# Developer key

Connect IQ sideload signing key lives here and is **not** committed.

Generate once:

```bash
mkdir -p keys
openssl genrsa -out keys/developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in keys/developer_key.pem -out keys/developer_key.der -nocrypt
```

`TacticalFace/build.sh` looks for `keys/developer_key.der` next to this folder, then `TacticalFace/keys/`.
