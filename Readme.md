# migrate_to_uv

A bash script to migrate your Python project from `requirements.txt` using pip to `uv` with a `pyproject.toml` and virtual environment management.

---

## Usage

You can run this script directly with `curl` or `wget` without manually downloading it.

### Using curl

```
curl -sL https://raw.githubusercontent.com/ragasimger/migrate_to_uv/main/migrate_to_uv.sh | bash -s -- --file=requirements.txt --venv=virtual_local
```
### Using wget

```
wget -qO- https://raw.githubusercontent.com/ragasimger/migrate_to_uv/main/migrate_to_uv.sh | bash -s -- --file=requirements.txt --venv=virtual_local
```

### Parameters

```
--file (optional) : Specify the requirements file (default: requirements.txt)

--venv (optional) : Specify the virtual environment folder name (default: .venv)
```


Example

```
curl -sL https://raw.githubusercontent.com/ragasimger/migrate_to_uv/main/migrate_to_uv.sh | bash -s -- --file=my-requirements.txt --venv=virtual_local
```
This will:

* Read dependencies from my-requirements.txt
* Create a virtual environment folder virtual_local
* Generate pyproject.toml with your dependencies
* Install dependencies using uv
* Create a locked requirements file requirements.lock.txt