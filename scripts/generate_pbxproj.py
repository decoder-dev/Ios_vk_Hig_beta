#!/usr/bin/env python3
"""Generate a minimal Xcode project.pbxproj for VKHIG (Linux-friendly scaffold)."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "VKHIG"
TEST_DIR = ROOT / "VKHIGTests"
OUT = ROOT / "VKHIG.xcodeproj" / "project.pbxproj"

def hid(name: str) -> str:
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()

swift_files = sorted(p for p in APP_DIR.rglob("*.swift"))
json_assets = sorted(
    p for p in (APP_DIR / "Resources" / "Assets.xcassets").rglob("*") if p.is_file()
)
resource_files = [
    APP_DIR / "Resources" / "PrivacyInfo.xcprivacy",
    APP_DIR / "Data" / "Fixtures" / "preview_data.json",
]
resource_files = [p for p in resource_files if p.exists()]
test_files = sorted(p for p in TEST_DIR.rglob("*.swift")) if TEST_DIR.exists() else []

PBX_BUILD_FILE = "PBXBuildFile"
PBX_FILE_REF = "PBXFileReference"
PBX_GROUP = "PBXGroup"
PBX_SOURCES = "PBXSourcesBuildPhase"
PBX_RESOURCES = "PBXResourcesBuildPhase"
PBX_FRAMEWORKS = "PBXFrameworksBuildPhase"
PBX_TARGET = "PBXNativeTarget"
PBX_PROJECT = "PBXProject"
PBX_CONFIG_LIST = "XCConfigurationList"
PBX_CONFIG = "XCBuildConfiguration"
PBX_PROXY = "PBXContainerItemProxy"
PBX_DEP = "PBXTargetDependency"

project_id = hid("PROJECT")
main_group = hid("MAINGROUP")
products_group = hid("PRODUCTS")
app_group = hid("APPGROUP")
tests_group = hid("TESTSGROUP")
app_target = hid("APPTARGET")
test_target = hid("TESTTARGET")
sources_phase = hid("SOURCES")
resources_phase = hid("RESOURCES")
frameworks_phase = hid("FRAMEWORKS")
test_sources_phase = hid("TESTSOURCES")
test_frameworks_phase = hid("TESTFRAMEWORKS")
project_configs = hid("PROJECTCONFIGS")
app_configs = hid("APPCONFIGS")
test_configs = hid("TESTCONFIGS")
debug_project = hid("DEBUGPROJECT")
release_project = hid("RELEASEPROJECT")
debug_app = hid("DEBUGAPP")
release_app = hid("RELEASEAPP")
debug_test = hid("DEBUGTEST")
release_test = hid("RELEASETEST")
app_product = hid("APPPRODUCT")
test_product = hid("TESTPRODUCT")
dep_id = hid("DEP")
proxy_id = hid("PROXY")

lines: list[str] = []
file_refs: dict[Path, str] = {}
build_files: dict[Path, str] = {}

def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")

# Collect refs
all_source_paths = swift_files + test_files
for path in all_source_paths + resource_files:
    file_refs[path] = hid(f"REF:{rel(path)}")
    build_files[path] = hid(f"BF:{rel(path)}")

assets_ref = hid("REF:Assets")
assets_bf = hid("BF:Assets")
info_ref = hid("REF:Info.plist")

lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tclasses = {};")
lines.append("\tobjectVersion = 56;")
lines.append("\tobjects = {")
lines.append("")

# Build files
lines.append(f"/* Begin {PBX_BUILD_FILE} section */")
for path in swift_files:
    lines.append(
        f"\t\t{build_files[path]} /* {path.name} in Sources */ = "
        f"{{isa = {PBX_BUILD_FILE}; fileRef = {file_refs[path]} /* {path.name} */; }};"
    )
for path in resource_files:
    lines.append(
        f"\t\t{build_files[path]} /* {path.name} in Resources */ = "
        f"{{isa = {PBX_BUILD_FILE}; fileRef = {file_refs[path]} /* {path.name} */; }};"
    )
lines.append(
    f"\t\t{assets_bf} /* Assets.xcassets in Resources */ = "
    f"{{isa = {PBX_BUILD_FILE}; fileRef = {assets_ref} /* Assets.xcassets */; }};"
)
for path in test_files:
    lines.append(
        f"\t\t{build_files[path]} /* {path.name} in Sources */ = "
        f"{{isa = {PBX_BUILD_FILE}; fileRef = {file_refs[path]} /* {path.name} */; }};"
    )
lines.append(f"/* End {PBX_BUILD_FILE} section */")
lines.append("")

# File refs
lines.append(f"/* Begin {PBX_FILE_REF} section */")
lines.append(
    f'\t\t{app_product} /* VK HIG.app */ = {{isa = {PBX_FILE_REF}; explicitFileType = wrapper.application; '
    f'includeInIndex = 0; path = "VK HIG.app"; sourceTree = BUILT_PRODUCTS_DIR; }};'
)
lines.append(
    f'\t\t{test_product} /* VKHIGTests.xctest */ = {{isa = {PBX_FILE_REF}; explicitFileType = wrapper.cfbundle; '
    f'includeInIndex = 0; path = VKHIGTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};'
)
for path in swift_files + test_files:
    lines.append(
        f'\t\t{file_refs[path]} /* {path.name} */ = {{isa = {PBX_FILE_REF}; lastKnownFileType = sourcecode.swift; '
        f'path = {path.name}; sourceTree = "<group>"; }};'
    )
for path in resource_files:
    ftype = "text.json" if path.suffix == ".json" else "text.plist.xml"
    lines.append(
        f'\t\t{file_refs[path]} /* {path.name} */ = {{isa = {PBX_FILE_REF}; lastKnownFileType = {ftype}; '
        f'path = {path.name}; sourceTree = "<group>"; }};'
    )
lines.append(
    f'\t\t{assets_ref} /* Assets.xcassets */ = {{isa = {PBX_FILE_REF}; lastKnownFileType = folder.assetcatalog; '
    f'path = Assets.xcassets; sourceTree = "<group>"; }};'
)
lines.append(
    f'\t\t{info_ref} /* Info.plist */ = {{isa = {PBX_FILE_REF}; lastKnownFileType = text.plist.xml; '
    f'path = Info.plist; sourceTree = "<group>"; }};'
)
lines.append(f"/* End {PBX_FILE_REF} section */")
lines.append("")

# Groups — flatten into logical folders by relative parent
folder_groups: dict[str, str] = {}
folder_children: dict[str, list[str]] = {}

def ensure_folder(rel_dir: str) -> str:
    if rel_dir in folder_groups:
        return folder_groups[rel_dir]
    gid = hid(f"GROUP:{rel_dir}")
    folder_groups[rel_dir] = gid
    folder_children[rel_dir] = []
    parent = str(Path(rel_dir).parent) if rel_dir not in ("VKHIG", "VKHIGTests", ".") else None
    if parent and parent not in (".", ""):
        ensure_folder(parent)
        folder_children[parent].append(f"{gid} /* {Path(rel_dir).name} */")
    return gid

ensure_folder("VKHIG")
ensure_folder("VKHIGTests")

# Place file refs into groups
for path in swift_files + resource_files:
    parent = str(path.parent.relative_to(ROOT))
    ensure_folder(parent)
    folder_children[parent].append(f"{file_refs[path]} /* {path.name} */")

# Assets + Info under Resources
resources_dir = "VKHIG/Resources"
ensure_folder(resources_dir)
folder_children[resources_dir].append(f"{assets_ref} /* Assets.xcassets */")
folder_children[resources_dir].append(f"{info_ref} /* Info.plist */")

for path in test_files:
    parent = str(path.parent.relative_to(ROOT))
    ensure_folder(parent)
    folder_children[parent].append(f"{file_refs[path]} /* {path.name} */")

# Nested subgroup refs only once at top-level children
# Rebuild children: only direct children files + direct subfolders
direct_children: dict[str, list[str]] = {k: [] for k in folder_groups}
for path in swift_files + resource_files + test_files:
    parent = str(path.parent.relative_to(ROOT))
    direct_children[parent].append(f"{file_refs[path]} /* {path.name} */")
direct_children[resources_dir].append(f"{assets_ref} /* Assets.xcassets */")
direct_children[resources_dir].append(f"{info_ref} /* Info.plist */")

for rel_dir, gid in folder_groups.items():
    for other, ogid in folder_groups.items():
        if other == rel_dir:
            continue
        if str(Path(other).parent) == rel_dir:
            direct_children[rel_dir].append(f"{ogid} /* {Path(other).name} */")

lines.append(f"/* Begin {PBX_GROUP} section */")
lines.append(f"\t\t{main_group} = {{")
lines.append(f"\t\t\tisa = {PBX_GROUP};")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{folder_groups['VKHIG']} /* VKHIG */,")
lines.append(f"\t\t\t\t{folder_groups['VKHIGTests']} /* VKHIGTests */,")
lines.append(f"\t\t\t\t{products_group} /* Products */,")
lines.append("\t\t\t);")
lines.append('\t\t\tsourceTree = "<group>";')
lines.append("\t\t};")
lines.append(f"\t\t{products_group} /* Products */ = {{")
lines.append(f"\t\t\tisa = {PBX_GROUP};")
lines.append("\t\t\tchildren = (")
lines.append(f'\t\t\t\t{app_product} /* VK HIG.app */,')
lines.append(f"\t\t\t\t{test_product} /* VKHIGTests.xctest */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Products;")
lines.append('\t\t\tsourceTree = "<group>";')
lines.append("\t\t};")

for rel_dir, gid in sorted(folder_groups.items()):
    name = Path(rel_dir).name
    lines.append(f"\t\t{gid} /* {name} */ = {{")
    lines.append(f"\t\t\tisa = {PBX_GROUP};")
    lines.append("\t\t\tchildren = (")
    for child in sorted(set(direct_children[rel_dir])):
        lines.append(f"\t\t\t\t{child},")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tpath = {name};")
    lines.append('\t\t\tsourceTree = "<group>";')
    lines.append("\t\t};")

lines.append(f"/* End {PBX_GROUP} section */")
lines.append("")

# Frameworks phases (empty)
lines.append(f"/* Begin {PBX_FRAMEWORKS} section */")
lines.append(f"\t\t{frameworks_phase} /* Frameworks */ = {{")
lines.append(f"\t\t\tisa = {PBX_FRAMEWORKS};")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"\t\t{test_frameworks_phase} /* Frameworks */ = {{")
lines.append(f"\t\t\tisa = {PBX_FRAMEWORKS};")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"/* End {PBX_FRAMEWORKS} section */")
lines.append("")

# Sources
lines.append(f"/* Begin {PBX_SOURCES} section */")
lines.append(f"\t\t{sources_phase} /* Sources */ = {{")
lines.append(f"\t\t\tisa = {PBX_SOURCES};")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in swift_files:
    lines.append(f"\t\t\t\t{build_files[path]} /* {path.name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"\t\t{test_sources_phase} /* Sources */ = {{")
lines.append(f"\t\t\tisa = {PBX_SOURCES};")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in test_files:
    lines.append(f"\t\t\t\t{build_files[path]} /* {path.name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"/* End {PBX_SOURCES} section */")
lines.append("")

# Resources
lines.append(f"/* Begin {PBX_RESOURCES} section */")
lines.append(f"\t\t{resources_phase} /* Resources */ = {{")
lines.append(f"\t\t\tisa = {PBX_RESOURCES};")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append(f"\t\t\t\t{assets_bf} /* Assets.xcassets in Resources */,")
for path in resource_files:
    lines.append(f"\t\t\t\t{build_files[path]} /* {path.name} in Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"/* End {PBX_RESOURCES} section */")
lines.append("")

# Targets
lines.append(f"/* Begin {PBX_TARGET} section */")
lines.append(f"\t\t{app_target} /* VKHIG */ = {{")
lines.append(f"\t\t\tisa = {PBX_TARGET};")
lines.append("\t\t\tbuildConfigurationList = " + app_configs + " /* Build configuration list for PBXNativeTarget \"VKHIG\" */;")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{sources_phase} /* Sources */,")
lines.append(f"\t\t\t\t{frameworks_phase} /* Frameworks */,")
lines.append(f"\t\t\t\t{resources_phase} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append("\t\t\t);")
lines.append('\t\t\tname = VKHIG;')
lines.append(f"\t\t\tproductName = VKHIG;")
lines.append(f'\t\t\tproductReference = {app_product} /* VK HIG.app */;')
lines.append('\t\t\tproductType = "com.apple.product-type.application";')
lines.append("\t\t};")
lines.append(f"\t\t{test_target} /* VKHIGTests */ = {{")
lines.append(f"\t\t\tisa = {PBX_TARGET};")
lines.append("\t\t\tbuildConfigurationList = " + test_configs + " /* Build configuration list for PBXNativeTarget \"VKHIGTests\" */;")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{test_sources_phase} /* Sources */,")
lines.append(f"\t\t\t\t{test_frameworks_phase} /* Frameworks */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append(f"\t\t\t\t{dep_id} /* PBXTargetDependency */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = VKHIGTests;")
lines.append("\t\t\tproductName = VKHIGTests;")
lines.append(f"\t\t\tproductReference = {test_product} /* VKHIGTests.xctest */;")
lines.append('\t\t\tproductType = "com.apple.product-type.bundle.unit-test";')
lines.append("\t\t};")
lines.append(f"/* End {PBX_TARGET} section */")
lines.append("")

# Project
lines.append(f"/* Begin {PBX_PROJECT} section */")
lines.append(f"\t\t{project_id} /* Project object */ = {{")
lines.append(f"\t\t\tisa = {PBX_PROJECT};")
lines.append("\t\t\tattributes = {")
lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
lines.append('\t\t\t\tLastSwiftUpdateCheck = 1600;')
lines.append("\t\t\t\tLastUpgradeCheck = 1600;")
lines.append("\t\t\t\tTargetAttributes = {")
lines.append(f"\t\t\t\t\t{app_target} = {{")
lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
lines.append("\t\t\t\t\t};")
lines.append(f"\t\t\t\t\t{test_target} = {{")
lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
lines.append("\t\t\t\t\t\tTestTargetID = " + app_target + ";")
lines.append("\t\t\t\t\t};")
lines.append("\t\t\t\t};")
lines.append("\t\t\t};")
lines.append(f"\t\t\tbuildConfigurationList = {project_configs} /* Build configuration list for PBXProject \"VKHIG\" */;")
lines.append('\t\t\tcompatibilityVersion = "Xcode 14.0";')
lines.append("\t\t\tdevelopmentRegion = ru;")
lines.append("\t\t\thasScannedForEncodings = 0;")
lines.append("\t\t\tknownRegions = (")
lines.append("\t\t\t\ten,")
lines.append("\t\t\t\tru,")
lines.append("\t\t\t\tBase,")
lines.append("\t\t\t);")
lines.append(f"\t\t\tmainGroup = {main_group};")
lines.append(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
lines.append('\t\t\tprojectDirPath = "";')
lines.append('\t\t\tprojectRoot = "";')
lines.append("\t\t\ttargets = (")
lines.append(f"\t\t\t\t{app_target} /* VKHIG */,")
lines.append(f"\t\t\t\t{test_target} /* VKHIGTests */,")
lines.append("\t\t\t);")
lines.append("\t\t};")
lines.append(f"/* End {PBX_PROJECT} section */")
lines.append("")

# Proxy / dependency
lines.append(f"/* Begin {PBX_PROXY} section */")
lines.append(f"\t\t{proxy_id} /* PBXContainerItemProxy */ = {{")
lines.append(f"\t\t\tisa = {PBX_PROXY};")
lines.append(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
lines.append("\t\t\tproxyType = 1;")
lines.append(f"\t\t\tremoteGlobalIDString = {app_target};")
lines.append('\t\t\tremoteInfo = VKHIG;')
lines.append("\t\t};")
lines.append(f"/* End {PBX_PROXY} section */")
lines.append("")
lines.append(f"/* Begin {PBX_DEP} section */")
lines.append(f"\t\t{dep_id} /* PBXTargetDependency */ = {{")
lines.append(f"\t\t\tisa = {PBX_DEP};")
lines.append(f"\t\t\ttarget = {app_target} /* VKHIG */;")
lines.append(f"\t\t\ttargetProxy = {proxy_id} /* PBXContainerItemProxy */;")
lines.append("\t\t};")
lines.append(f"/* End {PBX_DEP} section */")
lines.append("")

def config_block(cid: str, name: str, body: list[str]) -> None:
    lines.append(f"\t\t{cid} /* {name} */ = {{")
    lines.append(f"\t\t\tisa = {PBX_CONFIG};")
    lines.append("\t\t\tbuildSettings = {")
    for b in body:
        lines.append(f"\t\t\t\t{b}")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tname = {name};")
    lines.append("\t\t};")

shared = [
    'ALWAYS_SEARCH_USER_PATHS = NO;',
    'CLANG_ENABLE_MODULES = YES;',
    'CLANG_ENABLE_OBJC_ARC = YES;',
    'COPY_PHASE_STRIP = NO;',
    'ENABLE_STRICT_OBJC_MSGSEND = YES;',
    'GCC_C_LANGUAGE_STANDARD = gnu17;',
    'GCC_NO_COMMON_BLOCKS = YES;',
    'IPHONEOS_DEPLOYMENT_TARGET = 17.0;',
    'SDKROOT = iphoneos;',
    'SWIFT_VERSION = 5.0;',
]

lines.append(f"/* Begin {PBX_CONFIG} section */")
config_block(debug_project, "Debug", shared + [
    'DEBUG_INFORMATION_FORMAT = dwarf;',
    'ENABLE_TESTABILITY = YES;',
    'GCC_DYNAMIC_NO_PIC = NO;',
    'MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;',
    'ONLY_ACTIVE_ARCH = YES;',
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";',
    'SWIFT_OPTIMIZATION_LEVEL = "-Onone";',
])
config_block(release_project, "Release", shared + [
    'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";',
    'VALIDATE_PRODUCT = YES;',
    'SWIFT_COMPILATION_MODE = wholemodule;',
])
app_settings = [
    'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;',
    'CODE_SIGN_STYLE = Automatic;',
    'CURRENT_PROJECT_VERSION = 1;',
    'GENERATE_INFOPLIST_FILE = NO;',
    'INFOPLIST_FILE = VKHIG/Resources/Info.plist;',
    'LD_RUNPATH_SEARCH_PATHS = (',
    '\t"$(inherited)",',
    '\t"@executable_path/Frameworks",',
    ');',
    'MARKETING_VERSION = 0.1.0;',
    'PRODUCT_BUNDLE_IDENTIFIER = com.decoderdev.vkhig;',
    'PRODUCT_NAME = "VK HIG";',
    'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
    'SUPPORTS_MACCATALYST = NO;',
    'SWIFT_EMIT_LOC_STRINGS = YES;',
    'TARGETED_DEVICE_FAMILY = "1,2";',
]
config_block(debug_app, "Debug", app_settings)
config_block(release_app, "Release", app_settings)
test_settings = [
    'BUNDLE_LOADER = "$(TEST_HOST)";',
    'CODE_SIGN_STYLE = Automatic;',
    'CURRENT_PROJECT_VERSION = 1;',
    'GENERATE_INFOPLIST_FILE = YES;',
    'MARKETING_VERSION = 0.1.0;',
    'PRODUCT_BUNDLE_IDENTIFIER = com.decoderdev.vkhig.tests;',
    'PRODUCT_NAME = "$(TARGET_NAME)";',
    'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
    'SWIFT_EMIT_LOC_STRINGS = NO;',
    'TARGETED_DEVICE_FAMILY = "1,2";',
    'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/VK HIG.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/VK HIG";',
]
config_block(debug_test, "Debug", test_settings)
config_block(release_test, "Release", test_settings)
lines.append(f"/* End {PBX_CONFIG} section */")
lines.append("")

def config_list(cid: str, label: str, debug_id: str, release_id: str) -> None:
    lines.append(f"\t\t{cid} /* {label} */ = {{")
    lines.append(f"\t\t\tisa = {PBX_CONFIG_LIST};")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{debug_id} /* Debug */,")
    lines.append(f"\t\t\t\t{release_id} /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")

lines.append(f"/* Begin {PBX_CONFIG_LIST} section */")
config_list(project_configs, 'Build configuration list for PBXProject "VKHIG"', debug_project, release_project)
config_list(app_configs, 'Build configuration list for PBXNativeTarget "VKHIG"', debug_app, release_app)
config_list(test_configs, 'Build configuration list for PBXNativeTarget "VKHIGTests"', debug_test, release_test)
lines.append(f"/* End {PBX_CONFIG_LIST} section */")
lines.append("\t};")
lines.append(f"\trootObject = {project_id} /* Project object */;")
lines.append("}")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines) + "\n")
print(f"Wrote {OUT} with {len(swift_files)} app swift files, {len(test_files)} tests")
