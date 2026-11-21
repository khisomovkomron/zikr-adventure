#!/bin/zsh
# Creates a local signed archive/export. Does not upload or distribute a build.
set -euo pipefail
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID after Apple agreements are active}"
: "${ZIKR_TEAM_ID:?Set the team owning the existing App Store app}"
: "${ZIKR_EXPORT_DIR:?Choose an absolute output directory outside the repository}"
[[ "$ZIKR_EXPORT_DIR" == /* ]] || { print -u2 'Use an absolute output directory'; exit 2; }
TASK_ROOT="${0:A:h:h}"
[[ "$ZIKR_EXPORT_DIR" != "$TASK_ROOT" && "$ZIKR_EXPORT_DIR" != "$TASK_ROOT/"* ]] || { print -u2 'Export outside the repository'; exit 2; }
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ZIKR_AUTH_OPTIONS=()
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
  ZIKR_API_KEY_ID="${ASC_KEY_PATH:t:r}"
  ZIKR_API_KEY_ID="${ZIKR_API_KEY_ID#AuthKey_}"
  ZIKR_AUTH_OPTIONS=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ZIKR_API_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi
ZIKR_PREFLIGHT_RESULT="$(python3 "$TASK_ROOT/tools/testflight_preflight.py")"
# The operator must first apply/commit the build selected by --apply-build.
python3 - "$TASK_ROOT" "$ZIKR_PREFLIGHT_RESULT" <<'PY'
import json,pathlib,re,subprocess,sys
r=pathlib.Path(sys.argv[1]);p=r/'ZikrAdventure-1.0.1'
assert subprocess.check_output(['git','branch','--show-current'],cwd=r,text=True).strip()=='release/1.2.0', 'Archive only the accepted release/1.2.0 branch'
y=(p/'project.yml').read_text();x=(p/'ZikrAdventure.xcodeproj/project.pbxproj').read_text()
assert 'MARKETING_VERSION: "1.2.0"' in y and x.count('MARKETING_VERSION = 1.2.0;')==2
b=re.search(r'CURRENT_PROJECT_VERSION:\s*"?([0-9]+)',y)[1]
assert x.count(f'CURRENT_PROJECT_VERSION = {b};')==2
assert int(b)>json.loads(sys.argv[2])['last_uploaded_build'], 'Apply and commit a build above ASC before archiving'
assert not subprocess.check_output(['git','diff','HEAD','--','ZikrAdventure-1.0.1'],cwd=r), 'Commit source changes first'
PY
mkdir -p "$ZIKR_EXPORT_DIR"
python3 - "$ZIKR_EXPORT_DIR/ExportOptions.plist" "$ZIKR_TEAM_ID" <<'PY'
import plistlib,sys
with open(sys.argv[1],'wb') as f:
 plistlib.dump({'method':'app-store-connect','signingStyle':'automatic','teamID':sys.argv[2],
               'destination':'export','manageAppVersionAndBuildNumber':False},f)
PY
cd "$TASK_ROOT/ZikrAdventure-1.0.1"
xcodebuild archive -project ZikrAdventure.xcodeproj -scheme ZikrAdventure -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ZIKR_EXPORT_DIR/ZikrAdventure.xcarchive" \
  -derivedDataPath /private/tmp/zikr62-ios -jobs 2 -skipPackageUpdates \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO
# Preserve the app's requested capabilities in the intermediate archive. This ad-hoc
# signature is local only: exportArchive replaces it with App Store distribution signing.
# Without it an unsigned archive can lose Sign in with Apple during cloud export.
codesign --force --sign - --generate-entitlement-der \
  --entitlements "$TASK_ROOT/ZikrAdventure-1.0.1/ZikrAdventure/ZikrAdventure.entitlements" \
  "$ZIKR_EXPORT_DIR/ZikrAdventure.xcarchive/Products/Applications/ZikrAdventure.app"
xcodebuild -exportArchive -archivePath "$ZIKR_EXPORT_DIR/ZikrAdventure.xcarchive" \
  -exportPath "$ZIKR_EXPORT_DIR/ipa" -exportOptionsPlist "$ZIKR_EXPORT_DIR/ExportOptions.plist" \
  -allowProvisioningUpdates "${ZIKR_AUTH_OPTIONS[@]}"

ZIKR_IPAS=("$ZIKR_EXPORT_DIR"/ipa/*.ipa(N))
(( ${#ZIKR_IPAS} == 1 )) || { print -u2 'Expected exactly one exported IPA'; exit 2; }
python3 "$TASK_ROOT/tools/verify_testflight_ipa.py" "$ZIKR_IPAS[1]" --output "$ZIKR_EXPORT_DIR/verification.json"
