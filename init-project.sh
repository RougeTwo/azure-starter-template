#!/bin/bash

# ============================================
# Azure Project Setup Script
# ============================================

echo "=================================================="
echo "   Welcome to your Azure Project Setup"
echo "=================================================="
echo ""
echo "This script will guide you through setting up"
echo "your new Azure project step by step."
echo ""

# --- Step 1: Project Name ---
echo "Step 1: Project Name"
echo "--------------------"
echo "This is just a label for your project folder"
echo "and helps you identify it later."
read -p "Enter project name (e.g., data-pipeline): " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="my-azure-project"
    echo "Using default: $PROJECT_NAME"
fi
echo ""

# --- Step 2: Resource Group ---
echo "Step 2: Azure Resource Group"
echo "----------------------------"
echo "A Resource Group is like a folder that holds"
echo "all your Azure resources (storage, VMs, etc.)."
echo "If you want to use an existing one, type its name."
read -p "Enter Resource Group name (default: MyTestResourceGroup): " RG_NAME
RG_NAME=${RG_NAME:-MyTestResourceGroup}
echo "Using: $RG_NAME"
echo ""

# --- Step 3: Location (Region) ---
echo "Step 3: Azure Region (Location)"
echo "-------------------------------"
echo "This is where your resources will be physically hosted."
echo "Common options: southafricanorth, eastus, westeurope, uksouth"
read -p "Enter location (default: southafricanorth): " LOCATION
LOCATION=${LOCATION:-southafricanorth}
echo "Using: $LOCATION"
echo ""

# --- Step 4: Storage Account Name (Auto-generate) ---
echo "Step 4: Storage Account Name"
echo "----------------------------"
echo "Storage account names must be globally unique across Azure."
echo "We will generate a random name for you, but you can change it."
RANDOM_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
DEFAULT_STORAGE="store${RANDOM_SUFFIX}"
echo "Suggested name: $DEFAULT_STORAGE"
read -p "Enter storage account name (press Enter to accept suggestion): " STORAGE_NAME
STORAGE_NAME=${STORAGE_NAME:-$DEFAULT_STORAGE}
echo "Using: $STORAGE_NAME"
echo ""

# --- Step 5: Summary ---
echo "=================================================="
echo "              PROJECT SUMMARY"
echo "=================================================="
echo "Project Name      : $PROJECT_NAME"
echo "Resource Group    : $RG_NAME"
echo "Location          : $LOCATION"
echo "Storage Account   : $STORAGE_NAME"
echo "=================================================="
read -p "Does this look correct? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Setup cancelled. Run the script again."
    exit 1
fi

# --- Step 6: Save Configuration ---
echo "Saving configuration..."
cat > azure-config.json << CONF_EOF
{
  "projectName": "$PROJECT_NAME",
  "resourceGroup": "$RG_NAME",
  "location": "$LOCATION",
  "storageAccountName": "$STORAGE_NAME"
}
CONF_EOF

# Update the azure-config.md with the user's values
cat > azure-config.md << MD_EOF
# Azure Configuration for: $PROJECT_NAME

- **Resource Group**: $RG_NAME
- **Location**: $LOCATION
- **Storage Account**: $STORAGE_NAME

## Quick Commands
\`\`\`bash
az configure --defaults group=$RG_NAME location=$LOCATION
az deployment group create --resource-group $RG_NAME --template-file templates/storage-account.json --parameters storageAccountName=$STORAGE_NAME
\`\`\`
MD_EOF

echo ""
echo "✅ Setup complete!"
echo "Your configuration has been saved to:"
echo "  - azure-config.json"
echo "  - azure-config.md"
echo ""
echo "Next steps:"
echo "  1. Login to Azure:     az login"
echo "  2. Set defaults:       az configure --defaults group=$RG_NAME location=$LOCATION"
echo "  3. Deploy template:    az deployment group create --resource-group $RG_NAME --template-file templates/storage-account.json --parameters storageAccountName=$STORAGE_NAME"
echo ""
