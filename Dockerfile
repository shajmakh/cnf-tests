FROM registry.redhat.io/openshift4/ose-cli-rhel9:v4.21 AS oc

FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_9_golang_1.25 AS builder-latency-test-runners
ENV PKG_NAME=github.com/openshift-kni/cnf-tests
ENV PKG_PATH=/go/src/$PKG_NAME
RUN mkdir -p $PKG_PATH
COPY . $PKG_PATH/
WORKDIR $PKG_PATH
RUN go build -mod=vendor -o /oslat-runner ./cmd/oslat-runner && \
    go build -mod=vendor -o /cyclictest-runner ./cmd/cyclictest-runner && \
    go build -mod=vendor -o /hwlatdetect-runner ./cmd/hwlatdetect-runner

FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_9_golang_1.25 AS gobuilder
WORKDIR /app
COPY . .
RUN make test-bin

# Container runtime image
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

RUN microdnf install -y iproute \
      ethtool iputils procps-ng numactl-libs \
      kmod realtime-tests findutils \
      python3 # python3 is needed for hwlatdetect

COPY --from=oc /usr/bin/oc /usr/bin/oc
COPY --from=gobuilder /app/submodules/cluster-node-tuning-operator/build/_output/bin/latency-e2e.test /usr/bin/latency-e2e.test
COPY --from=gobuilder /app/entrypoint.sh /usr/bin/test-run.sh
COPY --from=builder-latency-test-runners /oslat-runner /usr/bin/oslat-runner
COPY --from=builder-latency-test-runners /cyclictest-runner /usr/bin/cyclictest-runner
COPY --from=builder-latency-test-runners /hwlatdetect-runner /usr/bin/hwlatdetect-runner

ENV OCP_VERSION=4.22
ENV IMAGE_REGISTRY=registry.redhat.io/openshift4/
ENV CNF_TESTS_IMAGE=cnf-tests-rhel9:v${OCP_VERSION}

CMD ["/usr/bin/test-run.sh"]

LABEL com.redhat.component="cnf-tests-container" \
      name="openshift4/cnf-tests-rhel9" \
      cpe="cpe:/a:redhat:openshift:4.22::el9" \
      summary="Latency verification tests image" \
      io.openshift.expose-services="" \
      io.openshift.tags="data,images" \
      io.k8s.display-name="cnf-tests" \
      io.openshift.maintainer.component="Telco latency tests image" \
      io.openshift.maintainer.product="OpenShift Container Platform" \
      io.k8s.description="Latency verification tests image" \
      maintainer="cnf-devel@redhat.com" \
      description="Latency verification tests image" \
      url="https://github.com/openshift-kni/cnf-tests"
