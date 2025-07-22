# Default values
REQ_FILE="requirements.txt"
VENV_NAME=".venv"

# Parsing the user input
for arg in "$@"; do
  case $arg in
    --file=*)
      REQ_FILE="${arg#*=}"
      shift
      ;;
    --venv=*)
      VENV_NAME="${arg#*=}"
      shift
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      echo "Usage: bash $0 --file=requirements.txt --venv=myenv"
      exit 1
      ;;
  esac
done

echo "📄 Using requirements file: $REQ_FILE"
echo "📁 Virtual environment name: $VENV_NAME"

# Check if requirements file exists
if [ ! -f "$REQ_FILE" ]; then
  echo "❌ File '$REQ_FILE' not found!"
  exit 1
fi

# Step 1: Installing uv if not available
if ! command -v uv &> /dev/null; then
  echo "🔄 uv not found. Installing..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.cargo/bin:$PATH"
  # Source the profile to make uv available in current session
  source "$HOME/.cargo/env" 2>/dev/null || true
else
  echo "✅ uv is already installed."
fi

# Verify uv is now available
if ! command -v uv &> /dev/null; then
  echo "❌ Failed to install or find uv. Please install manually."
  exit 1
fi

# Step 2: Generating pyproject.toml
echo "🛠️  Generating pyproject.toml..."
cat <<EOF > pyproject.toml
[project]
name = "uv-migrated-project"
version = "0.1.0"
description = "Migrated from requirements.txt to uv"
requires-python = ">=3.8"
dependencies = [
EOF

# Process requirements file, handling comments and empty lines
while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip comments and empty lines
  [[ "$line" =~ ^[[:space:]]*#.*$ || -z "${line// }" ]] && continue
  
  # Remove inline comments and trim whitespace
  clean_line=$(echo "$line" | sed 's/#.*$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  
  # Skip if line becomes empty after cleaning
  [[ -z "$clean_line" ]] && continue
  
  echo "    \"$clean_line\"," >> pyproject.toml
done < "$REQ_FILE"

cat <<EOF >> pyproject.toml
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
EOF

echo "✅ pyproject.toml created."

# Step 3: Creating virtual environment
echo "🐍 Creating virtual environment at ./$VENV_NAME..."
if [ -d "$VENV_NAME" ]; then
  echo "⚠️  Virtual environment '$VENV_NAME' already exists. Removing..."
  rm -rf "$VENV_NAME"
fi

uv venv "$VENV_NAME"

# Step 4: Installing packages using uv pip
echo "📦 Installing dependencies..."
# Use uv pip install with the virtual environment
uv pip install -r "$REQ_FILE" --python "$VENV_NAME/bin/python"

echo ""
echo "🎉 Migration complete!"
echo ""
echo "📋 What was created:"
echo "  • Virtual environment: $VENV_NAME/"
echo "  • Project file: pyproject.toml"
echo ""
echo "🚀 To activate your environment:"
echo "  source $VENV_NAME/bin/activate"
echo ""
echo "💡 Future uv commands:"
echo "  • Install packages: uv pip install <package>"
echo "  • Install from pyproject.toml: uv pip install -e ."
echo "  • Sync dependencies: uv pip sync requirements.txt"