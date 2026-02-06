#!/usr/bin/env bash

{

# DevOps-Utilities
# Copyright (C) 2025-2026  https://github.com/balsgh/DevOps-Utilities
#
# This file is part of DevOps-Utilities.
#
# DevOps-Utilities is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# DevOps-Utilities is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with DevOps-Utilities.  If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: GPL-3.0-or-later


#GET_AND_DECODE_SECRETS
unset -f GET_AND_DECODE_SECRETS; function GET_AND_DECODE_SECRETS() {
clear;
if ! kubectl config get-contexts -o name > /dev/null 2>&1; then
    echo -e "❌ \e[31mERROR:\e[00m No available kubectl contexts found in the kubeconfig file.";
else
    while : ; do
        mapfile -t CONTEXTS < <(kubectl config get-contexts -o name; echo "EXIT");
        echo -e "👉 \e[96mSELECT\e[00m a cluster CONTEXT to work with:";
        echo;
        unset REPLY; unset CONTEXT;
        PS3="Selection: ";
        select CONTEXT in "${CONTEXTS[@]}"; do
            if [[ ${REPLY} =~ ^[0-9]+$ && ${REPLY} -gt 0 && ${REPLY} -le ${#CONTEXTS[@]} ]]; then
                echo;
                echo -e "ℹ️  \e[36mINFO:\e[00m You picked [${REPLY}]:CONTEXT[${CONTEXT}]";
                echo;
                test "${CONTEXT}" = "EXIT" && break 2;
                while : ; do
                    mapfile -t NAMESPACES < <(kubectl --context "${CONTEXT}" get namespaces --no-headers=true | awk '{print $1}'; echo "SELECT_ANOTHER_CONTEXT"; echo "EXIT");
                    echo -e "👉 \e[96mSELECT\e[00m a NAMESPACE in /[${CONTEXT}] to work with:";
                    echo;
                    unset REPLY; unset NAMESPACE;
                    PS3="Selection: ";
                    select NAMESPACE in "${NAMESPACES[@]}"; do
                        if [[ ${REPLY} =~ ^[0-9]+$ && ${REPLY} -gt 0 && ${REPLY} -le ${#NAMESPACES[@]} ]]; then
                            echo;
                            echo -e "ℹ️  \e[36mINFO:\e[00m You picked [${REPLY}]:NAMESPACE[${NAMESPACE}]";
                            echo;
                            test "${NAMESPACE}" = "EXIT" && break 4;
                            test "${NAMESPACE}" = "SELECT_ANOTHER_CONTEXT" && break 3;
                            while : ; do
                                mapfile -t SECRETS < <(kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get secrets --no-headers | awk {'print $1'}; echo "SELECT_ANOTHER_NAMESPACE"; echo "SELECT_ANOTHER_CONTEXT"; echo "EXIT");
                                echo -e "👉 \e[96mSELECT\e[00m a SECRET in /[${CONTEXT}]/[${NAMESPACE}] to view its data:";
                                echo;
                                unset REPLY; unset SECRET;
                                PS3="Selection: ";
                                select SECRET in "${SECRETS[@]}"; do
                                    if [[ ${REPLY} =~ ^[0-9]+$ && ${REPLY} -gt 0 && ${REPLY} -le ${#SECRETS[@]} ]]; then
                                        echo;
                                        echo -e "ℹ️  \e[36mINFO:\e[00m You picked [${REPLY}]:SECRET[${SECRET}]";
                                        echo;
                                        test "${SECRET}" = "EXIT" && break 6;
                                        test "${SECRET}" = "SELECT_ANOTHER_CONTEXT" && break 5;
                                        test "${SECRET}" = "SELECT_ANOTHER_NAMESPACE" && break 3;
                                        while : ; do
                                            mapfile -t KEYS < <(kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get secret "${SECRET}" -o=yaml | yq '.data' | cut -d: -f1; echo "SELECT_ANOTHER_SECRET"; echo "SELECT_ANOTHER_NAMESPACE"; echo "SELECT_ANOTHER_CONTEXT"; echo "EXIT");
                                            echo -e "👉 \e[96mSELECT\e[00m a KEY in /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}] to view its value:";
                                            echo;
                                            unset REPLY; unset KEY;
                                            PS3="Selection: ";
                                            select KEY in "${KEYS[@]}"; do
                                                if [[ ${REPLY} =~ ^[0-9]+$ && ${REPLY} -gt 0 && ${REPLY} -le ${#KEYS[@]} ]]; then
                                                    echo;
                                                    echo -e "ℹ️  \e[36mINFO:\e[00m You picked [${REPLY}]:KEY[${KEY}]";
                                                    echo;
                                                    test "${KEY}" = "EXIT" && break 8;
                                                    test "${KEY}" = "SELECT_ANOTHER_CONTEXT" && break 7;
                                                    test "${KEY}" = "SELECT_ANOTHER_NAMESPACE" && break 5;
                                                    test "${KEY}" = "SELECT_ANOTHER_SECRET" && break 3;
                                                    VALUE_ENCODED="$(kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get secret "${SECRET}" -o=yaml | yq ".data.\"${KEY}\"")";
                                                    if [[ -z "${VALUE_ENCODED}" || "${VALUE_ENCODED}" = '""' ]]; then
                                                        echo -e "\e[35mWARNING:\e[00m /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}]/.data.[${KEY}]=[${VALUE_ENCODED}]";
                                                        echo -e "\e[35mWARNING:\e[00m [$(kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get secret "${SECRET}" -o=yaml | yq ".data" | grep -E "^${KEY}: ")]";
                                                    else
                                                        if [[ "${KEY}" =~ ^(tls.crt|ca.crt)$ ]]; then
                                                            if ( openssl x509 -noout -subject -issuer -dates -in <(echo "${VALUE_ENCODED}" | base64 -d) > /dev/null 2>&1 ); then 
                                                                echo -e "✅ \e[32mSUCCESS:\e[00m /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}]/.data.[${KEY}]:";
                                                                # openssl x509 -noout -text -in <(echo "${VALUE_ENCODED}" | base64 -d); echo;
                                                                openssl storeutl -noout -text -certs <(echo "${VALUE_ENCODED}" | base64 -d) | \
                                                                    grep --color=always -E \
                                                                        -e "^([[:digit:]])+: Certificate$" \
                                                                        -e "Serial Number:" \
                                                                        -e "^[[:space:]]{12}([[:xdigit:]]{2}:){15}[[:xdigit:]]{2}$" \
                                                                        -e "Issuer:" \
                                                                        -e "Not Before:" \
                                                                        -e "Not After :" \
                                                                        -e "Subject:" \
                                                                        -e "CN=" \
                                                                        -e "Subject Alternative Name:" \
                                                                        -e "DNS:" \
                                                                        -e "Total found:";
                                                            else
                                                                echo -e "❌ \e[31mERROR:\e[00m Unable to decode certificate at /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}]/.data.[${KEY}]:";
                                                                echo -e "❌ \e[31mERROR:\e[00m Base64 ENCODED returned value was; \n[${VALUE_ENCODED}\n]";
                                                                echo -e "❌ \e[31mERROR:\e[00m Base64 DECODED returned value was; \n[$(echo "${VALUE_ENCODED}" | base64 -d)]\n";
                                                            fi;
                                                        elif [[ "${KEY}" = "tls.key" ]]; then
                                                            echo "${VALUE_ENCODED}" | base64 -d | openssl rsa --noout -check;
                                                            VAR_MODULUS_KEY=$(echo "${VALUE_ENCODED}" | base64 -d | openssl rsa -modulus -noout | openssl md5 | awk '{print $2}');
                                                            VAR_MODULUS_CERT=$(kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get secret "${SECRET}" -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -modulus -noout | openssl md5 | awk '{print $2}');
                                                            if [[ "${VAR_MODULUS_KEY}" = "${VAR_MODULUS_CERT}" ]]; then
                                                                echo -e "✅ \e[32mSUCCESS:\e[00m MATCH /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}]/.data.[${KEY}] + /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}]/.data.tls.crt";
                                                            else
                                                                echo -e "❌ \e[31mERROR:\e[00m MISMATCH /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}]/.data.[${KEY}] + /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}]/.data.tls.crt";
                                                            fi;
                                                        else
                                                            echo -e "✅ \e[32mSUCCESS:\e[00m /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}]/.data.[${KEY}] = [\n$(echo "${VALUE_ENCODED}" | base64 -d)\n]";
                                                        fi;
                                                    fi;
	                                                  echo;
                                                    break 1;
                                                else
                                                    echo;
                                                    echo -e "❌ \e[31mERROR:\e[00m User Input Error - $(test -z "${REPLY}" && echo -e "Nothing was entered" || echo -e "You entered [${REPLY}]") - Please select a valid value from the available list.";
                                                    echo;
                                                    echo -e "🔁 \e[34mRETRY:\e[00mPlease try again"'!!!';
                                                    echo;
                                                fi;
                                            done;
                                        done;
                                    else
                                        echo;
                                        echo -e "❌ \e[31mERROR:\e[00m User Input Error - $(test -z "${REPLY}" && echo -e "Nothing was entered" || echo -e "You entered [${REPLY}]") - Please select a valid value from the available list.";
                                        echo;
                                        echo -e "🔁 \e[34mRETRY:\e[00mPlease try again"'!!!';
                                        echo;
                                    fi;
                                done;
                            done;
                        else
                            echo;
                            echo -e "❌ \e[31mERROR:\e[00m User Input Error - $(test -z "${REPLY}" && echo -e "Nothing was entered" || echo -e "You entered [${REPLY}]") - Please select a valid value from the available list.";
                            echo;
                            echo -e "🔁 \e[34mRETRY:\e[00mPlease try again"'!!!';
                            echo;
                        fi;
                    done;
                done;
            else
                echo;
                echo -e "❌ \e[31mERROR:\e[00m User Input Error - $(test -z "${REPLY}" && echo -e "Nothing was entered" || echo -e "You entered [${REPLY}]") - Please select a valid value from the available list.";
                echo;
                echo -e "🔁 \e[34mRETRY:\e[00mPlease try again"'!!!';
                echo;
            fi;
        done;
    done;
fi;
}
GET_AND_DECODE_SECRETS;
}
