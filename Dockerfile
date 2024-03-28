FROM ghcr.io/oracle/oci-cli:latest

ENV OCI_CLI_AUTH="instance_principal"

USER root

RUN yum install -y bash jq dnsutils curl

COPY nsg-rule-editor.sh /

USER oracle

ENTRYPOINT [ "/nsg-rule-editor.sh" ]
