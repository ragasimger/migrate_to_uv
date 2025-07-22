# Default values
REQ_FILE="requirements.txt"
VENV_NAME=".venv"
PYTHON_VERSION=""

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
    --python=*)
      PYTHON_VERSION="${arg#*=}"
      shift
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      echo "Usage: bash $0 --file=requirements.txt --venv=myenv --python=3.11"
      exit 1
      ;;
  esac
done

echo "📄 Using requirements file: $REQ_FILE"
echo "📁 Virtual environment name: $VENV_NAME"
if [ -n "$PYTHON_VERSION" ]; then
  echo "🐍 Target Python version: $PYTHON_VERSION"
else
  echo "🐍 Using system default Python"
fi

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

# Step 2: Check and validate Python version if specified
if [ -n "$PYTHON_VERSION" ]; then
  echo "🔍 Checking Python version $PYTHON_VERSION availability..."
  
  # Try to find the specified Python version
  PYTHON_EXECUTABLE=""
  
  # Check common Python executable patterns
  for py_cmd in "python$PYTHON_VERSION" "python${PYTHON_VERSION%.*}" "python3" "python"; do
    if command -v "$py_cmd" &> /dev/null; then
      # Get the actual version and check if it matches
      actual_version=$($py_cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
      if [ "$actual_version" = "$PYTHON_VERSION" ]; then
        PYTHON_EXECUTABLE="$py_cmd"
        echo "✅ Found Python $PYTHON_VERSION at: $(which $py_cmd)"
        break
      fi
    fi
  done
  
  # If not found, check if uv can manage it
  if [ -z "$PYTHON_EXECUTABLE" ]; then
    echo "⚠️  Python $PYTHON_VERSION not found in system PATH."
    echo "🔄 Checking if uv can install Python $PYTHON_VERSION..."
    
    # Try to install Python with uv
    if uv python install "$PYTHON_VERSION" 2>/dev/null; then
      echo "✅ Python $PYTHON_VERSION installed by uv."
      PYTHON_EXECUTABLE="python$PYTHON_VERSION"
    else
      echo "❌ Error: Python $PYTHON_VERSION is not available and cannot be installed by uv."
      echo ""
      echo "💡 Please install Python $PYTHON_VERSION manually:"
      echo "   • On macOS: brew install python@$PYTHON_VERSION"
      echo "   • On Ubuntu/Debian: sudo apt install python$PYTHON_VERSION python$PYTHON_VERSION-venv"
      echo "   • On CentOS/RHEL: sudo yum install python$PYTHON_VERSION"
      echo "   • Or download from: https://www.python.org/downloads/"
      exit 1
    fi
  fi
else
  # Use default Python
  PYTHON_EXECUTABLE="python3"
  if ! command -v "$PYTHON_EXECUTABLE" &> /dev/null; then
    PYTHON_EXECUTABLE="python"
  fi
  
  if ! command -v "$PYTHON_EXECUTABLE" &> /dev/null; then
    echo "❌ No Python executable found. Please install Python."
    exit 1
  fi
  
  # Get the version for display
  DETECTED_VERSION=$($PYTHON_EXECUTABLE -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
  echo "✅ Using Python $DETECTED_VERSION at: $(which $PYTHON_EXECUTABLE)"
fi

# Step 3: Generating pyproject.toml
echo "🛠️  Generating pyproject.toml..."

# Determine Python version requirement for pyproject.toml
if [ -n "$PYTHON_VERSION" ]; then
  PYTHON_REQUIREMENT=">=$PYTHON_VERSION"
else
  # Get the current Python version and use it as minimum
  CURRENT_VERSION=$($PYTHON_EXECUTABLE -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
  PYTHON_REQUIREMENT=">=$CURRENT_VERSION"
fi

cat <<EOF > pyproject.toml
[project]
name = "uv-migrated-project"
version = "0.1.0"
description = "Migrated from requirements.txt to uv"
requires-python = "$PYTHON_REQUIREMENT"
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

# Step 4: Creating virtual environment
echo "🐍 Creating virtual environment at ./$VENV_NAME..."
if [ -d "$VENV_NAME" ]; then
  echo "⚠️  Virtual environment '$VENV_NAME' already exists. Removing..."
  rm -rf "$VENV_NAME"
fi

# Create virtual environment with specific Python version
if [ -n "$PYTHON_VERSION" ]; then
  uv venv "$VENV_NAME" --python "$PYTHON_VERSION"
else
  uv venv "$VENV_NAME" --python "$PYTHON_EXECUTABLE"
fi

# Step 5: Installing packages using uv pip
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
echo "  • Install packages: uv pip install <package> --python $VENV_NAME/bin/python"
echo "  • Install from pyproject.toml: uv pip install -e . --python $VENV_NAME/bin/python"
echo "  • Sync dependencies: uv pip sync requirements.txt --python $VENV_NAME/bin/python"