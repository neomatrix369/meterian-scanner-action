#!/bin/bash

set -e
set -o pipefail

if [[ "$INPUT_CLI_ARGS" =~ --debug ]]; then
    set -x
fi

# rust-specifics
chmod -R 777 /opt/rust/

export ORIGINAL_PATH=$PATH

length() {
    arg="${1:-}"
    echo ${#arg}
}

OSS="$INPUT_OSS"
if [[ "$OSS" == "true" ]]; then
    export OSS_TRUE="-Dcli.oss.enabled=true"
else
    # check that the Meterian API token is correctly set
    METERIAN_API_TOKEN=${METERIAN_API_TOKEN:?'METERIAN_API_TOKEN missing. Ensure that this secret is set correctly.'}
fi

# prepare the script file and version file
cp /root/meterian.sh /tmp/meterian.sh
cp /root/version.txt /tmp/version.txt
export METERIAN_CLI_ARGS="$INPUT_CLI_ARGS"

autofix_security_program=""
if [[ -n "${INPUT_AUTOFIX_SECURITY:-}" ]]; then
    autofix_security_program+="${INPUT_AUTOFIX_SECURITY}+vulns+no-overrides"
fi

autofix_stability_program=""
if [[ -n "${INPUT_AUTOFIX_STABILITY:-}" ]]; then
    autofix_stability_program+="${INPUT_AUTOFIX_STABILITY}+dated+no-overrides"
fi

autofix_final_program=""
autofix_final_program+="$autofix_security_program,$autofix_stability_program"

second_last_char_index=$(($(length $autofix_final_program) - 1))
if [[ "${autofix_final_program:$second_last_char_index}" == "," ]]; then
    autofix_final_program="${autofix_final_program:0:$second_last_char_index}"
fi

if [[ -n "${INPUT_AUTOFIX_WITH_ISSUE:-}" || -n "${INPUT_AUTOFIX_WITH_PR:-}" || -n "${INPUT_AUTOFIX_WITH_REPORT:-}" ]];then
    autofix_flag="--autofix"
    if [[ -n "$autofix_final_program" ]]; then
        autofix_flag+=":$autofix_final_program"
    fi

    report_pdf_flag=""
    if [[ -n "${INPUT_AUTOFIX_WITH_REPORT:-}" ]]; then
        report_pdf_flag="--report-pdf=report.pdf"
    fi

    if [[ -n "${PR_MODE:-}" ]]; then
        pr_mode="--pullreqs:$PR_MODE"
    else
        pr_mode="--pullreqs"
    fi

    export METERIAN_CLI_ARGS="$METERIAN_CLI_ARGS $autofix_flag $pr_mode $report_pdf_flag"
fi

# creating user meterian necessary for dependency management tools that require it (e.g. cocoapods)
currDir=$(pwd)
WITH_HUID="-ou $(stat -c '%u' "${currDir}")"
WITH_HGID="-g $(stat -c '%g' "${currDir}") -o"

groupadd ${WITH_HGID} meterian
useradd -g meterian ${WITH_HUID} meterian -d /home/meterian

# creating home dir if it doesn't exist
if [[ ! -d "/home/meterian" ]];
then
    mkdir /home/meterian
fi

# changing home dir group and ownership
chown meterian:meterian /home/meterian

set +e
# launch meterian client with the newly created user
if [[ "$METERIAN_CLI_ARGS" =~ --debug ]]; then
    su meterian -c -m /tmp/meterian.sh
else
    su meterian -c -m /tmp/meterian.sh 2> /dev/null
fi
cliExitCode=$?
set -e

if [[ "$METERIAN_CLI_ARGS" =~ --debug ]]; then
    meterian_pr_debug_log="-l DEBUG"
else
    meterian_pr_debug_log=""
fi

if [[ -n "${ALWAYS_OPEN_PRS:-}" ]];then
    always_open_prs_flag="--always-open-prs"
else
    always_open_prs_flag=""
fi

if [[ -n "${INPUT_AUTOFIX_WITH_PR:-}" ]];then
	meterian-pr . PR ${GITHUB_REPOSITORY} ${GITHUB_REF_NAME} $meterian_pr_debug_log $always_open_prs_flag --record-prs
fi

if [[ -n "${INPUT_AUTOFIX_WITH_REPORT:-}" ]];then
	meterian-pr . PR ${GITHUB_REPOSITORY} ${GITHUB_REF_NAME} $meterian_pr_debug_log $always_open_prs_flag --with-pdf-report $(pwd)/report.pdf --record-prs
fi

if [[ -n "${INPUT_AUTOFIX_WITH_ISSUE:-}" ]];then
	meterian-pr . ISSUE ${GITHUB_REPOSITORY} ${GITHUB_REF_NAME} $meterian_pr_debug_log
fi

exit $cliExitCode