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
  -disableAutomaticPackageResolution -allowProvisioningUpdates DEVELOPMENT_TEAM="$ZIKR_TEAM_ID" CODE_SIGN_STYLE=Automatic
xcodebuild -exportArchive -archivePath "$ZIKR_EXPORT_DIR/ZikrAdventure.xcarchive" \
  -exportPath "$ZIKR_EXPORT_DIR/ipa" -exportOptionsPlist "$ZIKR_EXPORT_DIR/ExportOptions.plist" \
  -allowProvisioningUpdates
