cd ~/my-projects/my-new-azure-project || exit

cat > init-project.sh << 'EOF'
#!/bin/bash

# ============================================
# Azure Project Setup Script (Interactive + Auto-Deploy)
# ============================================

# Default values
PROJECT_NAME=""
RG_NAME="MyTestResourceGroup"
LOCATION="southafricanorth"
STORAGE_NAME=""

# Parse command-line arguments (for future use)
while getopts "n:r:l:s:h" opt; do
  case $opt in
    n) PROJECT_NAME="$OPTARG" ;;
    r) RG_NAME="$OPTARG" ;;
    l) LOCATION="$OPTARG" ;;
    s) STORAGE_NAME="$OPTARG" ;;
    h)
      echo "Usage: ./init-project.sh [options]"
      echo "  -n <name>      Project name"
      echo "  -r <rg>        Resource Group (default: MyTestResourceGroup)"
      echo "  -l <location>  Azure region (default: southafricanorth)"
      echo "  -s <storage>   Storage account name (auto-generates if omitted)"
      echo "  -h             Show this help"
      exit 0
      ;;
  esac
done

# If arguments are provided, run in AUTO mode (skip questions)
if [ -n "$PROJECT_NAME" ] || [ -n "$STORAGE_NAME" ]; then
  AUTO_MODE=1
else
  AUTO_MODE=0
fi

echo "=================================================="
echo "   Welcome to your Azure Project Setup"
echo "=================================================="
echo ""

# --- Step 1: Project Name ---
if [ $AUTO_MODE -eq 1 ] && [ -n "$PROJECT_NAME" ]; then
  echo "Using project name: $PROJECT_NAME"
else
  echo "Step 1: Project Name"
  echo "--------------------"
  echo "This is just a label for your project folder."
  read -p "Enter project name (e.g., data-pipeline): " PROJECT_NAME
  PROJECT_NAME=${PROJECT_NAME:-"my-azure-project"}
fi

# --- Step 2: Resource Group ---
if [ $AUTO_MODE -eq 1 ] && [ -n "$RG_NAME" ]; then
  echo "Using Resource Group: $RG_NAME"
else
  echo ""
  echo "Step 2: Azure Resource Group"
  echo "----------------------------"
  read -p "Enter Resource Group name (default: MyTestResourceGroup): " input_rg
  RG_NAME=${input_rg:-"MyTestResourceGroup"}
fi

# --- Step 3: Location ---
if [ $AUTO_MODE -eq 1 ] && [ -n "$LOCATION" ]; then
  echo "Using location: $LOCATION"
else
  echo ""
  echo "Step 3: Azure Region (Location)"
  echo "-------------------------------"
  read -p "Enter location (default: southafricanorth): " input_loc
  LOCATION=${input_loc:-"southafricanorth"}
fi

# --- Step 4: Storage Account Name ---
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

# --- Step 5: Summary & Confirmation (skip if auto) ---
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

# --- Step 6: Save Configuration ---
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

echo ""
echo "✅ Setup complete! Configuration saved."

# --- Step 7: ASK TO DEPLOY AUTOMATICALLY (THIS FIXES YOUR CONCERN!) ---
echo ""
read -p "Do you want to deploy the storage account to Azure NOW? (y/n): " DEPLOY_NOW

if [[ "$DEPLOY_NOW" =~ ^[Yy]$ ]]; then
  echo ""
  echo "🚀 Deploying your storage account..."
  echo "Setting defaults..."
  az configure --defaults group=$RG_NAME location=$LOCATION

  echo "Running deployment..."
  az deployment group create \
    --resource-group $RG_NAME \
    --template-file templates/storage-account.json \
    --parameters storageAccountName=$STORAGE_NAME

  if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment SUCCEEDED!"
    echo "Your storage account '$STORAGE_NAME' is now live in Azure."
    echo "View it in the portal: https://portal.azure.com/#resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME"
  else
    echo ""
    echo "❌ Deployment failed. Please check the error messages above."
  fi
else
  echo ""
  echo "Skipping deployment. You can deploy later using:"
  echo "az deployment group create --resource-group $RG_NAME --template-file templates/storage-account.json --parameters storageAccountName=$STORAGE_NAME"
fi

echo ""
echo "All done! Happy coding 🚀"
EOF

chmod +x init-project.sh
