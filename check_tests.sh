#!/bin/bash
# Script checking the errors.txt file generated by the test.sh script

set -u

set -o allexport
source env.list
source env-distrib.list

DIR_TEST="/workspace/test_docker-ce-${DOCKER_VERS}_containerd-${CONTAINERD_VERS}"
PATH_TEST_ERRORS="${DIR_TEST}/errors.txt"

# Check if there is a errors.txt file
if ! test -f ${PATH_TEST_ERRORS}
then
    echo "There is no file ${PATH_TEST_ERRORS} with the errors." 2>&1 | tee -a ${LOG}
    CHECK_TESTS_BOOL="ERR"
fi

# Check that for each distrib of each packtype, we have a build log and a test log
# Get the number of distros (x2 because we have docker-ce packages but also static binaries)
NB_DEBS=$(eval "awk -F\- '{print NF-1}' /workspace/env-distrib.list | awk 'NR==1'")
NB_RPMS=$(eval "awk -F\- '{print NF-1}' /workspace/env-distrib.list | awk 'NR==2'")
NB_DISTROS=$(expr $(expr ${NB_DEBS} + ${NB_RPMS}) \* 2)

# Get the number of the build and test logs
NB_BUILD_LOGS=$(eval "find ${DIR_TEST}/build* | wc -l")
NB_TEST_LOGS=$(eval "find ${DIR_TEST}/test* | wc -l")

echo "Nb of build logs : ${NB_BUILD_LOGS}" 2>&1 | tee -a ${LOG}
echo "Nb of test logs : ${NB_TEST_LOGS}" 2>&1 | tee -a ${LOG}

DISTROS=$(eval "echo $DEBS $RPMS | tr '-' '_'")

if [[ ${NB_BUILD_LOGS} -ne 0 ]] && [[ ${NB_TEST_LOGS} -ne 0 ]]
then
    # If we have at least 1 build log and at least 1 test log
    if [[ ${NB_BUILD_LOGS} == ${NB_DISTROS} ]] && [[ ${NB_TEST_LOGS} == ${NB_DISTROS} ]]
    then
        # We have the exact number of build and test logs
        # Check if there are any 1 in the ${PATH_TEST_ERRORS}
        echo "# Check the file #" 2>&1 | tee -a ${LOG}
        TOTAL_ERRORS=$(eval "grep -c 1 ${PATH_TEST_ERRORS}")
        if [[ ${TOTAL_ERRORS} -eq 0 ]]
        then
            echo "There is no error in the test log files. We can push to the shared COS Bucket. " 2>&1 | tee -a ${LOG}
            # Push NO ERROR
            CHECK_TESTS_BOOL="NOERR"
        else
            echo "We have every log but there are errors in the test log files. " 2>&1 | tee -a ${LOG}
            # Push ERROR
            CHECK_TESTS_BOOL="ERR"
        fi
    else
        # We don't have the exact number of build and test logs
        # Push to COS bucket ERR
        echo "There are build or test log files missing. " 2>&1 | tee -a ${LOG}
        # Check which build or test log files are missing
        for DISTRO in ${DISTROS}
        do
            TEST_LOG="${DIR_TEST}/test_${DISTRO}.log"
            find ${TEST_LOG}
            if [[ $? -ne 0 ]]
            then
                # Print the DISTRO in the {PATH_TEST_ERRORS}
                DISTRO_NAME="$(cut -d'-' -f1 <<<"${DISTRO}")"
                DISTRO_VERS="$(cut -d'-' -f2 <<<"${DISTRO}")"
                echo "DISTRO ${DISTRO_NAME} ${DISTRO_VERS}" 2>&1 | tee -a ${PATH_TEST_ERRORS}
                echo "Missing" 2>&1 | tee -a ${PATH_TEST_ERRORS}
            fi
        done
        TOTAL_MISSING=$(eval "grep -c "Missing" ${PATH_TEST_ERRORS}")
        TOTAL_ERRORS=$(eval "grep -c 1 ${PATH_TEST_ERRORS}")
        echo "There are ${TOTAL_MISSING} test log files missing and there are ${TOTAL_ERRORS} errors for the existing test log files." 2>&1 | tee -a ${LOG}
        # Push ERROR
        CHECK_TESTS_BOOL="ERR"

    fi
else
    # There are 0 build logs or 0 test logs
    echo "There are no build logs or no test logs." 2>&1 | tee -a ${LOG}
    # Push ERROR
    CHECK_TESTS_BOOL="ERR"
fi
