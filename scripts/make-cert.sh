#!/bin/sh
# Creates a self-signed "Timetracker Dev" code signing identity in the login keychain so that
# macOS keeps the Accessibility grant across rebuilds (ad-hoc signatures change on every build).
set -e
NAME="Timetracker Dev"
if security find-identity -p codesigning 2>/dev/null | grep -q "\"$NAME\""; then echo "$NAME already exists"; exit 0; fi
T=$(mktemp -d)
openssl req -x509 -newkey rsa:2048 -keyout "$T/key.pem" -out "$T/cert.pem" -days 3650 -nodes -subj "/CN=$NAME" \
  -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" -addext "basicConstraints=critical,CA:false" 2>/dev/null
openssl pkcs12 -export -legacy -out "$T/dev.p12" -inkey "$T/key.pem" -in "$T/cert.pem" -passout pass:tt -name "$NAME"
security import "$T/dev.p12" -k ~/Library/Keychains/login.keychain-db -P tt -T /usr/bin/codesign -T /usr/bin/security
rm -rf "$T"
echo "Created $NAME"
