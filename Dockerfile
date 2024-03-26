FROM python:3 as downloader

ARG oci_cli_version="3.7.0"

RUN python -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH" \
    OCI_CLI_VERSION="${oci_cli_version}"

WORKDIR /

RUN wget https://github.com/oracle/oci-cli/releases/download/v${OCI_CLI_VERSION}/oci-cli-${OCI_CLI_VERSION}.zip && \
  unzip -j oci-cli-${OCI_CLI_VERSION}.zip oci-cli/oci_cli-${OCI_CLI_VERSION}-py3-none-any.whl && \
  pip install -U pip setuptools wheel && \
  pip install "cython<3.0.0" && pip install --no-build-isolation pyyaml==5.4.1 && \
  pip install oci_cli-${OCI_CLI_VERSION}-py3-none-any.whl

FROM python:3 as ocicli

COPY --from=downloader /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

FROM ocicli as oci-nsg-rule-editor

ENV OCI_CLI_AUTH="instance_principal"

RUN apt update
RUN apt install jq dnsutils -y

COPY nsg-rule-editor.sh /

ENTRYPOINT [ "/nsg-rule-editor.sh" ]
