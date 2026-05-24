# Configure Azure Cost Management exports

A reproducible, click-by-click guide to setting up the daily blob exports that feed this accelerator.

You can configure exports either via the **Azure portal** or via **Azure CLI / PowerShell / Bicep**. Both are below.

---

## Option 1 — Azure portal

### Step 1 — Create the storage account & container

If you don't already have one:

1. Portal → **Storage accounts** → **+ Create**
2. Settings:
   - Subscription / Resource group: your finance / shared-services RG
   - Storage account name: `finops<env>` (e.g. `finopsprd`, must be globally unique)
   - Region: same region as the majority of your Azure footprint
   - Performance: **Standard**
   - Redundancy: **LRS** (these are append-only daily files; geo-redundancy not needed)
3. **Review + create** → **Create**
4. Once provisioned: open the storage account → **Containers** → **+ Container**
   - Name: `cost-analysis`
   - Public access level: **Private**
   - **Create**

### Step 2 — Create the Cost Management export

1. Portal → **Cost Management + Billing** → pick the right Billing scope (Billing account, Subscription, or Resource group)
2. **Cost Management → Exports** → **+ Add**
3. Configure:
   - **Export name:** `Daily-MTD-Costs-Classic` (or whatever convention you use)
   - **Metric:** *Actual cost (Usage and Purchases)*
   - **Export type:** *Daily export of month-to-date costs*
   - **Start date:** today
4. **Storage destination:**
   - Subscription: the subscription holding your storage account
   - Storage account: `finops<env>` from Step 1
   - Container: `cost-analysis`
   - Directory: leave blank (or `mca/` if you want path-separation)
   - File format: **CSV**
   - File compression: **GZIP** (smaller files = faster Power BI refresh)
5. **Review + create → Create**
6. Click your new export → **Run now** to seed the first file (otherwise you'll wait up to 24h).

### Step 3 — (Optional but recommended) FOCUS export

Repeat Step 2, with one change:

- **Export type:** *FOCUS*
- **Export name:** `Daily-MTD-Costs-FOCUS`
- Drop into the **same** container and **same** directory — the accelerator's M code handles both file formats.

### Step 4 — Grant Power BI the right to read

For the account that will run the dataset refresh in Power BI Service:

1. Storage account → **Access Control (IAM)** → **+ Add → Add role assignment**
2. Role: **Storage Blob Data Reader**
3. Assign access to: **User, group, or service principal**
4. Select the user / SP that will own the dataset refresh
5. **Review + assign**

Wait ~5 minutes for the role to propagate before testing in Power BI.

---

## Option 2 — Azure CLI (scriptable)

```bash
# Variables
RG=rg-finops
LOC=westeurope
STG=finopsprd$RANDOM
CONTAINER=cost-analysis
SUB_ID=$(az account show --query id -o tsv)

# 1. Create resource group + storage account
az group create -n $RG -l $LOC

az storage account create \
  -g $RG -n $STG \
  -l $LOC --sku Standard_LRS --kind StorageV2

# 2. Create container
az storage container create \
  --account-name $STG -n $CONTAINER --auth-mode login

# 3. Create the daily MCA export
az costmanagement export create \
  --scope "/subscriptions/$SUB_ID" \
  --name "Daily-MTD-Costs-Classic" \
  --storage-account-id "/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$STG" \
  --storage-container $CONTAINER \
  --timeframe MonthToDate \
  --recurrence Daily \
  --recurrence-period from="$(date -u +%Y-%m-%dT00:00:00Z)" to="$(date -u -d '+1 year' +%Y-%m-%dT00:00:00Z)" \
  --type ActualCost \
  --schedule-status Active

# 4. Trigger the first run immediately
az costmanagement export run \
  --scope "/subscriptions/$SUB_ID" \
  --name "Daily-MTD-Costs-Classic"

# 5. Grant the Power BI service principal read access
PBI_SP_ID="<service-principal-object-id>"
az role assignment create \
  --assignee $PBI_SP_ID \
  --role "Storage Blob Data Reader" \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$STG"

echo "Storage account: https://$STG.blob.core.windows.net"
echo "Container: $CONTAINER"
echo "Plug those into the .pbit on first open."
```

---

## Option 3 — Bicep (infra-as-code)

```bicep
// File: deploy/finops-storage.bicep
param location string = resourceGroup().location
param storageAccountName string = 'finopsprd${uniqueString(resourceGroup().id)}'
param containerName string = 'cost-analysis'

resource stg 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: stg
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobSvc
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}

output storageAccountUrl string = stg.properties.primaryEndpoints.blob
output containerName string = containerName
```

Deploy:

```bash
az group create -n rg-finops -l westeurope
az deployment group create \
  -g rg-finops \
  -f deploy/finops-storage.bicep
```

The export itself can't yet be created in Bicep (no resource provider) — use the CLI step from Option 2 or do that one step in the portal.

---

## Verification checklist

Before opening the `.pbit`, confirm:

- [ ] At least one `.csv` or `.csv.gz` file (not a manifest) exists in the container
- [ ] Your Power BI account has *Storage Blob Data Reader* on the storage account
- [ ] Storage account firewall is either open or has Power BI Service IPs allow-listed (Service-only scenario)
- [ ] You can browse the container in Storage Explorer / portal with your account

If all four are ✅, the `.pbit` will load on first try.
