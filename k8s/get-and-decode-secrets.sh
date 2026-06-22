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


# Bash 3.2 (macOS default) lacks mapfile; read stdin lines into array named by $1
_lines_to_array() {
    local _name="$1" _line
    eval "${_name}=()"
    while IFS= read -r _line; do
        eval "${_name}+=(\"\${_line}\")"
    done
}

# printf %b interprets \e etc. on Bash 3.2+ and Linux (echo -e does not on macOS)
say() { printf '%b\n' "$*"; }

_b64_decode() { echo "$1" | base64 -d 2>/dev/null; }

_is_x509_certificate() {
    _b64_decode "$1" | openssl x509 -noout -subject > /dev/null 2>&1
}

_is_private_key() {
    _b64_decode "$1" | openssl pkey -noout > /dev/null 2>&1
}

_key_name_suggests_certificate() {
    [[ "$1" =~ \.(crt|cer|pem)$ || "$1" =~ ^(tls\.crt|ca\.crt)$ ]] && [[ ! "$1" =~ \.key(\.pem)?$ ]]
}

_key_name_suggests_private_key() {
    [[ "$1" = "tls.key" || "$1" =~ \.key(\.pem)?$ ]]
}

_show_decoded_certificate() {
    local _ctx="$1" _ns="$2" _secret="$3" _key="$4" _b64="$5"
    if _is_x509_certificate "${_b64}"; then
        say "✅ \e[32mSUCCESS:\e[00m /[${_ctx}]/[${_ns}]/[${_secret}]/.data.[${_key}]:";
        openssl storeutl -noout -text -certs <(_b64_decode "${_b64}") | \
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
        return 0
    fi
    say "❌ \e[31mERROR:\e[00m Unable to decode certificate at /[${_ctx}]/[${_ns}]/[${_secret}]/.data.[${_key}]:";
    say "❌ \e[31mERROR:\e[00m Base64 ENCODED returned value was; \n[${_b64}\n]";
    say "❌ \e[31mERROR:\e[00m Base64 DECODED returned value was; \n[$(_b64_decode "${_b64}")\n]";
    return 1
}

_find_secret_certificate_b64() {
    local _ctx="$1" _ns="$2" _secret="$3" _keys _key _val
    _val="$(kubectl --context "${_ctx}" -n "${_ns}" get secret "${_secret}" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)"
    if [[ -n "${_val}" ]] && _is_x509_certificate "${_val}"; then
        echo "${_val}"
        return 0
    fi
    _lines_to_array _keys < <(kubectl --context "${_ctx}" -n "${_ns}" get secret "${_secret}" -o=yaml | yq '.data' | cut -d: -f1)
    for _key in "${_keys[@]}"; do
        _val="$(kubectl --context "${_ctx}" -n "${_ns}" get secret "${_secret}" -o=yaml | yq ".data.\"${_key}\"")"
        if _is_x509_certificate "${_val}"; then
            echo "${_val}"
            return 0
        fi
    done
    return 1
}

_show_decoded_private_key() {
    local _ctx="$1" _ns="$2" _secret="$3" _key="$4" _b64="$5" _cert_b64 _mod_key _mod_cert
    if ! _is_private_key "${_b64}"; then
        say "❌ \e[31mERROR:\e[00m Unable to decode private key at /[${_ctx}]/[${_ns}]/[${_secret}]/.data.[${_key}]:";
        say "❌ \e[31mERROR:\e[00m Base64 DECODED returned value was; \n[$(_b64_decode "${_b64}")\n]";
        return 1
    fi
    _b64_decode "${_b64}" | openssl pkey -noout -check 2>/dev/null || _b64_decode "${_b64}" | openssl pkey -noout
    if _b64_decode "${_b64}" | openssl rsa -noout -check > /dev/null 2>&1; then
        _cert_b64="$(_find_secret_certificate_b64 "${_ctx}" "${_ns}" "${_secret}")" || true
        if [[ -n "${_cert_b64}" ]]; then
            _mod_key="$(_b64_decode "${_b64}" | openssl rsa -modulus -noout | openssl md5 | awk '{print $2}')"
            _mod_cert="$(_b64_decode "${_cert_b64}" | openssl x509 -modulus -noout | openssl md5 | awk '{print $2}')"
            if [[ "${_mod_key}" = "${_mod_cert}" ]]; then
                say "✅ \e[32mSUCCESS:\e[00m MATCH /[${_ctx}]/[${_ns}]/[${_secret}]/.data.[${_key}] + secret certificate data";
            else
                say "❌ \e[31mERROR:\e[00m MISMATCH /[${_ctx}]/[${_ns}]/[${_secret}]/.data.[${_key}] + secret certificate data";
            fi
        else
            say "✅ \e[32mSUCCESS:\e[00m /[${_ctx}]/[${_ns}]/[${_secret}]/.data.[${_key}] (no certificate found in secret for modulus check)";
        fi
    else
        say "✅ \e[32mSUCCESS:\e[00m /[${_ctx}]/[${_ns}]/[${_secret}]/.data.[${_key}] (non-RSA private key)";
    fi
}

#GET_AND_DECODE_SECRETS
unset -f GET_AND_DECODE_SECRETS; function GET_AND_DECODE_SECRETS() {
clear;
if ! kubectl config get-contexts -o name > /dev/null 2>&1; then
    say "❌ \e[31mERROR:\e[00m No available kubectl contexts found in the kubeconfig file.";
else
    while : ; do
        _lines_to_array CONTEXTS < <(kubectl config get-contexts -o name; echo "EXIT");
        say "👉 \e[96mSELECT\e[00m a cluster CONTEXT to work with:";
        echo;
        unset REPLY; unset CONTEXT;
        PS3="Selection: ";
        select CONTEXT in "${CONTEXTS[@]}"; do
            if [[ ${REPLY} =~ ^[0-9]+$ && ${REPLY} -gt 0 && ${REPLY} -le ${#CONTEXTS[@]} ]]; then
                echo;
                say "ℹ️  \e[36mINFO:\e[00m You picked [${REPLY}]:CONTEXT[${CONTEXT}]";
                echo;
                test "${CONTEXT}" = "EXIT" && break 2;
                while : ; do
                    _lines_to_array NAMESPACES < <(kubectl --context "${CONTEXT}" get namespaces --no-headers=true | awk '{print $1}'; echo "SELECT_ANOTHER_CONTEXT"; echo "EXIT");
                    say "👉 \e[96mSELECT\e[00m a NAMESPACE in /[${CONTEXT}] to work with:";
                    echo;
                    unset REPLY; unset NAMESPACE;
                    PS3="Selection: ";
                    select NAMESPACE in "${NAMESPACES[@]}"; do
                        if [[ ${REPLY} =~ ^[0-9]+$ && ${REPLY} -gt 0 && ${REPLY} -le ${#NAMESPACES[@]} ]]; then
                            echo;
                            say "ℹ️  \e[36mINFO:\e[00m You picked [${REPLY}]:NAMESPACE[${NAMESPACE}]";
                            echo;
                            test "${NAMESPACE}" = "EXIT" && break 4;
                            test "${NAMESPACE}" = "SELECT_ANOTHER_CONTEXT" && break 3;
                            while : ; do
                                _lines_to_array SECRETS < <(kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get secrets --no-headers | awk '$1 !~ /^sh\.helm\.release/ {print $1}'; echo "SELECT_ANOTHER_NAMESPACE"; echo "SELECT_ANOTHER_CONTEXT"; echo "EXIT");
                                say "👉 \e[96mSELECT\e[00m a SECRET in /[${CONTEXT}]/[${NAMESPACE}] to view its data:";
                                echo;
                                unset REPLY; unset SECRET;
                                PS3="Selection: ";
                                select SECRET in "${SECRETS[@]}"; do
                                    if [[ ${REPLY} =~ ^[0-9]+$ && ${REPLY} -gt 0 && ${REPLY} -le ${#SECRETS[@]} ]]; then
                                        echo;
                                        say "ℹ️  \e[36mINFO:\e[00m You picked [${REPLY}]:SECRET[${SECRET}]";
                                        echo;
                                        test "${SECRET}" = "EXIT" && break 6;
                                        test "${SECRET}" = "SELECT_ANOTHER_CONTEXT" && break 5;
                                        test "${SECRET}" = "SELECT_ANOTHER_NAMESPACE" && break 3;
                                        while : ; do
                                            _lines_to_array KEYS < <(kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get secret "${SECRET}" -o=yaml | yq '.data' | cut -d: -f1; echo "SELECT_ANOTHER_SECRET"; echo "SELECT_ANOTHER_NAMESPACE"; echo "SELECT_ANOTHER_CONTEXT"; echo "EXIT");
                                            say "👉 \e[96mSELECT\e[00m a KEY in /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}] to view its value:";
                                            echo;
                                            unset REPLY; unset KEY;
                                            PS3="Selection: ";
                                            select KEY in "${KEYS[@]}"; do
                                                if [[ ${REPLY} =~ ^[0-9]+$ && ${REPLY} -gt 0 && ${REPLY} -le ${#KEYS[@]} ]]; then
                                                    echo;
                                                    say "ℹ️  \e[36mINFO:\e[00m You picked [${REPLY}]:KEY[${KEY}]";
                                                    echo;
                                                    test "${KEY}" = "EXIT" && break 8;
                                                    test "${KEY}" = "SELECT_ANOTHER_CONTEXT" && break 7;
                                                    test "${KEY}" = "SELECT_ANOTHER_NAMESPACE" && break 5;
                                                    test "${KEY}" = "SELECT_ANOTHER_SECRET" && break 3;
                                                    VALUE_ENCODED="$(kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get secret "${SECRET}" -o=yaml | yq ".data.\"${KEY}\"")";
                                                    if [[ -z "${VALUE_ENCODED}" || "${VALUE_ENCODED}" = '""' ]]; then
                                                        say "\e[35mWARNING:\e[00m /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}]/.data.[${KEY}]=[${VALUE_ENCODED}]";
                                                        say "\e[35mWARNING:\e[00m [$(kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get secret "${SECRET}" -o=yaml | yq ".data" | grep -E "^${KEY}: ")]";
                                                    else
                                                        if _is_x509_certificate "${VALUE_ENCODED}" || _key_name_suggests_certificate "${KEY}"; then
                                                            _show_decoded_certificate "${CONTEXT}" "${NAMESPACE}" "${SECRET}" "${KEY}" "${VALUE_ENCODED}";
                                                        elif _is_private_key "${VALUE_ENCODED}" || _key_name_suggests_private_key "${KEY}"; then
                                                            _show_decoded_private_key "${CONTEXT}" "${NAMESPACE}" "${SECRET}" "${KEY}" "${VALUE_ENCODED}";
                                                        else
                                                            say "✅ \e[32mSUCCESS:\e[00m /[${CONTEXT}]/[${NAMESPACE}]/[${SECRET}]/.data.[${KEY}] = [\n$(_b64_decode "${VALUE_ENCODED}")\n]";
                                                        fi;
                                                    fi;
	                                                  echo;
                                                    break 1;
                                                else
                                                    echo;
                                                    say "❌ \e[31mERROR:\e[00m User Input Error - $(test -z "${REPLY}" && say "Nothing was entered" || say "You entered [${REPLY}]") - Please select a valid value from the available list.";
                                                    echo;
                                                    say "🔁 \e[34mRETRY:\e[00mPlease try again"'!!!';
                                                    echo;
                                                fi;
                                            done;
                                        done;
                                    else
                                        echo;
                                        say "❌ \e[31mERROR:\e[00m User Input Error - $(test -z "${REPLY}" && say "Nothing was entered" || say "You entered [${REPLY}]") - Please select a valid value from the available list.";
                                        echo;
                                        say "🔁 \e[34mRETRY:\e[00mPlease try again"'!!!';
                                        echo;
                                    fi;
                                done;
                            done;
                        else
                            echo;
                            say "❌ \e[31mERROR:\e[00m User Input Error - $(test -z "${REPLY}" && say "Nothing was entered" || say "You entered [${REPLY}]") - Please select a valid value from the available list.";
                            echo;
                            say "🔁 \e[34mRETRY:\e[00mPlease try again"'!!!';
                            echo;
                        fi;
                    done;
                done;
            else
                echo;
                say "❌ \e[31mERROR:\e[00m User Input Error - $(test -z "${REPLY}" && say "Nothing was entered" || say "You entered [${REPLY}]") - Please select a valid value from the available list.";
                echo;
                say "🔁 \e[34mRETRY:\e[00mPlease try again"'!!!';
                echo;
            fi;
        done;
    done;
fi;
}
GET_AND_DECODE_SECRETS;
}
