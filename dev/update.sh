#!/usr/bin/env bash
set -euo pipefail
. "${BASH_SOURCE[0]%/*}/run-in-nix-env" "curl git minisign" "$@"

trap 'echo "Error at ${BASH_SOURCE[0]}:$LINENO"' ERR

# The well known public key for Zig (https://ziglang.org/download/)
zig_pubkey="RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U"

dry_run=
test_all=
push=
for arg in "$@"; do
    case "$arg" in
        # Don't make any persistent changes
        --dry-run|-n)
            dry_run=1
            ;;
        --test-all|-t)
            test_all=1
            ;;
        # Create a commit and push to upstream
        --push|-p)
            push=1
            ;;
        *)
            echo "Error: unknown option '$arg'"
            exit 1
            ;;
    esac
done

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Fetch rev of Zig master
cd "${BASH_SOURCE[0]%/*}"

echo "Checking for new Zig master release"

index_json=$(curl -fsS 'https://ziglang.org/download/index.json')
master_version=$(echo "$index_json" | jq -r .master.version)
master_rev_short=${master_version##*+}
master_rev=$(
    curl -fsS -L "https://codeberg.org/api/v1/repos/ziglang/zig/commits/$master_rev_short/status" \
        | jq -r .sha
)
if [[ $push && ! $dry_run ]]; then
    git checkout HEAD -- ../zig-release.nix
fi
current_rev=$(nix eval --raw -f ../zig-release.nix src.rev)

if [[ $master_rev == $current_rev ]]; then
    echo "zig-release.nix is already up to date"
    exit
fi

minisig=$(curl -fsS "https://ziglang.org/builds/zig-${master_version}-index.json.minisig")
minisign -Vq -P "$zig_pubkey" -x <(echo "$minisig") -m <(echo "$index_json")
echo "Valid signature for 'index.json'"

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Fetch upstream/master to master, but only when:
# - upstream/master has new commits
# - just file `zig-release.nix` has changed in upstream
# - master can be fast-forwarded to upstream
#
# This allows multiple maintainers of `nix-zig-build` to run this
# update script independently from each other.

if [[ $push ]]; then
    if [[ $(git rev-parse --abbrev-ref HEAD) != master ]]; then
        echo 'Error: Branch `master` is currently not checked out'
        exit 1
    fi
    if ! git diff-index --quiet HEAD; then
        echo 'Error: This repo has uncommitted changes'
        exit 1
    fi

    echo "Checking for upstream changes"

    git fetch upstream master -q

    if git merge-base --is-ancestor upstream/master master; then
        echo "Upstream has no new commits"
    else
        if ! git merge-base --is-ancestor master upstream/master; then
            echo "Can't set master to upstream."
            echo "Master can't be fast-forwarded to upstream/master."
            exit 1
        fi
        changed_files=($(git diff --name-only master upstream/master))
        num_changed_files=${#changed_files[@]}
        if [[ ! ($num_changed_files == 0 || ($num_changed_files == 1 && ${changed_files[0]} == zig-release.nix)) ]]; then
            echo "Can't set master to upstream."
            echo 'Files other than `zig-release.nix` have changed between master and upstream/master:'
            printf '  %s\n' "${changed_files[@]}" | grep -v zig-release.nix
            echo '(via `git diff --name-only master upstream/master`)'
            exit 1
        fi
        if [[ ! $dry_run ]]; then
            git switch upstream/master --force-create master -q
        fi
    fi
fi

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Update ../zig-release.nix

echo "Getting Nix content hash of Zig src"
master_hash=$(nix hash convert --hash-algo sha256 "$(
  nix-prefetch-url --unpack "https://codeberg.org/ziglang/zig/archive/$master_rev.tar.gz" 2>/dev/null
)")
x86_64_sha256=$(echo "$index_json" | jq -r '.master."x86_64-linux".shasum');
aarch64_sha256=$(echo "$index_json" | jq -r '.master."aarch64-linux".shasum');
echo \
"{
  version = \"$master_version\";
  src = {
    rev = \"$master_rev\";
    hash = \"$master_hash\";
  };
  binaries = {
    x86_64-linux.sha256 = \"$x86_64_sha256\";
    aarch64-linux.sha256 = \"$aarch64_sha256\";
  };
}" > ../zig-release.nix

if [[ ! $dry_run && $push ]]; then
    git add ../zig-release.nix
fi

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Test Zig build
echo "Running test"
if [[ $test_all ]]; then
    ./test.sh test_all
else
    ./test.sh test_pkg
fi

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Create commit and push to upstream
if [[ $dry_run ]]; then
    git checkout HEAD -- ../zig-release.nix
else
    commit_msg="update to Zig \`$master_version\`"
    if [[ $push ]]; then
        git commit -m "$commit_msg [auto]"
        git push upstream master
    else
        echo "$commit_msg"
    fi
fi
