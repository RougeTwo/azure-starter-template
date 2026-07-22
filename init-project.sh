cd ~/my-projects/my-new-azure-project || exit

cat > init-project.sh << 'EOF'
#!/bin/bash

# ============================================
# Azure Project Setup Script (Interactive + CLI + Auto-Deploy)
# ============================================
# This script bootstraps a new Azure project by:
#   - Collecting project details (name, RG, location, storage)
#   - Saving configuration files
#   - Optionally deploying ARM templates (Storage, VNet, Web App)
# ============================================

set -e  # Exit on any error

# -------------------------------
# 1. Parse command-line arguments
# -------------------------------
PROJECT_NAME=""
RG_NAME="MyTestResourceGroup"
LOCATION="southafricanorth"
STORAGE_NAME=""

while getopts "n:r:l:s:h" opt; do
  case $opt in
    n) PROJECT_NAME="$OPTARG" ;;
    r) RG_NAME="$OPTARG" ;;
    l) LOCATION="$OPTARG" ;;
    s) STORAGE_NAME="$OPTARG" ;;
    h)
      echo "Usage: ./init-project.sh [options]"
      echo "  -n <name>      Project name (label)"
      echo "  -r <rg>        Resource Group (default: MyTestResourceGroup)"
      echo "  -l <location>  Azure region (default: southafricanorth)"
      echo "  -s <storage>   Storage account name (auto-generated if omitted)"
      echo "  -h             Show this help"
      exit 0
      ;;
  esac
done

# If arguments are provided, run in AUTO mode (skip interactive questions where possible)
if [ -n "$PROJECT_NAME" ] || [ -n "$STORAGE_NAME" ]; then
  AUTO_MODE=1
else
  AUTO_MODE=0
fi

echo "=================================================="
echo "   Welcome to your Azure Project Setup"
echo "=================================================="
echo ""

# ---------------------------------------
# 2. Collect user input (or use arguments)
# ---------------------------------------

# Step 1: Project Name
if [ $AUTO_MODE -eq 1 ] && [ -n "$PROJECT_NAME" ]; then
  echo "Using project name: $PROJECT_NAME"
else
  echo "Step 1: Project Name"
  echo "--------------------"
  echo "This is just a label for your project folder."
  read -p "Enter project name (e.g., data-pipeline): " input_name
  PROJECT_NAME=${input_name:-"my-azure-project"}
fi

# Step 2: Resource Group
if [ $AUTO_MODE -eq 1 ] && [ -n "$RG_NAME" ]; then
  echo "Using Resource Group: $RG_NAME"
else
  echo ""
  echo "Step 2: Azure Resource Group"
  echo "----------------------------"
  read -p "Enter Resource Group name (default: MyTestResourceGroup): " input_rg
  RG_NAME=${input_rg:-"MyTestResourceGroup"}
fi

# Step 3: Location
if [ $AUTO_MODE -eq 1 ] && [ -n "$LOCATION" ]; then
  echo "Using location: $LOCATION"
else
  echo ""
  echo "Step 3: Azure Region (Location)"
  echo "-------------------------------"
  read -p "Enter location (default: southafricanorth): " input_loc
  LOCATION=${input_loc:-"southafricanorth"}
fi

# Step 4: Storage Account Name (generate if not provided)
if [ $AUTO_MODE -eq 1 ] && [ -n "$STORAGE_NAME" ]; then
  echo "Using storage name: $STORAGE_NAME"
else
  echo ""
  echo "Step 4: Storage Account Name"
  echo "----------------------------"
  RANDOM_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
  SUGGESTED="store${RANDOM_SUFFIX}"
  echo "Suggested name: $SUGGESTED"
  read -p "Enter storage account name (press Enter to accept suggestion): " input_storage
  STORAGE_NAME=${input_storage:-$SUGGESTED}
fi

# ---------------------------------------
# 3. Summary and confirmation
# ---------------------------------------
echo ""
echo "=================================================="
echo "              PROJECT SUMMARY"
echo "=================================================="
echo "Project Name      : $PROJECT_NAME"
echo "Resource Group    : $RG_NAME"
echo "Location          : $LOCATION"
echo "Storage Account   : $STORAGE_NAME"
echo "=================================================="

if [ $AUTO_MODE -eq 0 ]; then
  read -p "Does this look correct? (y/n): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Setup cancelled. Run the script again."
    exit 1
  fi
else
  echo "Auto-mode: Skipping confirmation."
fi

# ---------------------------------------
# 4. Save configuration files
# ---------------------------------------
echo ""
echo "Saving configuration..."
cat > azure-config.json << CONF_EOF
{
  "projectName": "$PROJECT_NAME",
  "resourceGroup": "$RG_NAME",
  "location": "$LOCATION",
  "storageAccountName": "$STORAGE_NAME"
}
CONF_EOF

cat > azure-config.md << MD_EOF
# Azure Configuration for: $PROJECT_NAME

- **Resource Group**: $RG_NAME
- **Location**: $LOCATION
- **Storage Account**: $STORAGE_NAME
MD_EOF

echo "✅ Configuration saved to azure-config.json and azure-config.md"

# ---------------------------------------
# 5. Check if user is logged in to Azure
# ---------------------------------------
echo ""
echo "Checking Azure login status..."
if ! az account show &>/dev/null; then
  echo "❌ You are not logged in to Azure."
  read -p "Do you want to log in now? (y/n): " login_now
  if [[ "$login_now" =~ ^[Yy]$ ]]; then
    az login
  else
    echo "Skipping deployment. Run 'az login' later and then deploy manually."
    exit 0
  fi
else
  echo "✅ Already logged in to Azure."
fi

# ---------------------------------------
# 6. Ask to deploy resources
# ---------------------------------------
echo ""
read -p "Do you want to deploy resources to Azure NOW? (y/n): " DEPLOY_NOW

if [[ ! "$DEPLOY_NOW" =~ ^[Yy]$ ]]; then
  echo "Skipping deployment. You can deploy later using the commands in azure-config.md"
  exit 0
fi

# ---------------------------------------
# 7. Resource selection menu
# ---------------------------------------
echo ""
echo "Select resources to deploy (enter space-separated numbers):"
echo "  1) Storage Account   (templates/storage-account.json)"
echo "  2) Virtual Network   (templates/virtual-network.json)"
echo "  3) Web App + App Plan (templates/app-service.json)"
echo "  4) Deploy ALL resources"
echo "  0) Skip deployment"
read -p "Enter choice(s) (e.g., '1 2' or '4'): " -a CHOICES

# If choice 4 is selected, override with all numbers
if [[ " ${CHOICES[@]} " =~ " 4 " ]]; then
  CHOICES=(1 2 3)
fi

# ---------------------------------------
# 8. Deploy selected resources
# ---------------------------------------
echo ""
echo "🚀 Starting deployment(s)..."

# Set defaults (so we don't need to specify --resource-group each time)
az configure --defaults group="$RG_NAME" location="$LOCATION"

for choice in "${CHOICES[@]}"; do
  case $choice in
    1)
      echo "Deploying Storage Account..."
      az deployment group create \
        --resource-group "$RG_NAME" \
        --template-file templates/storage-account.json \
        --parameters storageAccountName="$STORAGE_NAME"
      ;;
    2)
      echo "Deploying Virtual Network..."
      az deployment group create \
        --resource-group "$RG_NAME" \
        --template-file templates/virtual-network.json \
        --parameters vnetName="${PROJECT_NAME}-vnet" addressPrefix="10.0.0.0/16"
      ;;
    3)
      echo "Deploying Web App + App Plan..."
      # Generate a unique web app name (lowercase, alphanumeric, max 60 chars)
      UNIQUE_WEBAPP="${PROJECT_NAME//-}web$(date +%s | tail -c 6)"
      az deployment group create \
        --resource-group "$RG_NAME" \
        --template-file templates/app-service.json \
        --parameters webAppName="$UNIQUE_WEBAPP" sku="F1"
      ;;
    0)
      echo "No resources selected."
      ;;
    *)
      echo "Invalid choice: $choice"
      ;;
  esac
done

# ---------------------------------------
# 9. Final summary
# ---------------------------------------
echo ""
echo "=================================================="
echo "✅ All selected deployments completed!"
echo "Resources are now live in Azure."
echo ""
echo "Resource Group: $RG_NAME"
echo "Storage Account: $STORAGE_NAME"
echo ""
echo "View in Azure Portal: https://portal.azure.com"
echo "=================================================="
EOF

chmod +x init-project.sh
