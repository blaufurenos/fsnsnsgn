##########################################
#         构建可执行二进制文件             #
##########################################
# 指定构建的基础镜像
FROM golang:alpine AS builder

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ

# 镜像变量
ARG DOCKER_IMAGE=danxiaonuo/trojan-go
ENV DOCKER_IMAGE=$DOCKER_IMAGE
ARG DOCKER_IMAGE_OS=golang
ENV DOCKER_IMAGE_OS=$DOCKER_IMAGE_OS
ARG DOCKER_IMAGE_TAG=alpine
ENV DOCKER_IMAGE_TAG=$DOCKER_IMAGE_TAG
ARG BUILD_DATE
ENV BUILD_DATE=$BUILD_DATE
ARG VCS_REF
ENV VCS_REF=$VCS_REF

ARG BUILD_DEPS="\
      git \
      make"
ENV BUILD_DEPS=$BUILD_DEPS

# 修改源地址
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
# ***** 安装依赖 *****
RUN set -eux \
   # 更新源地址
   && apk update \
   # 更新系统并更新系统软件
   && apk upgrade && apk upgrade \
   && apk add -U --update $BUILD_DEPS \
   # 更新时区
   && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
   # 更新时间
   && echo ${TZ} > /etc/timezone

# 运行工作目录
WORKDIR /build
# 克隆源码运行安装
RUN git clone --depth=1 --progress https://github.com/p4gefau1t/trojan-go.git /src && \
    cd /src && make &&\
    wget https://github.com/v2fly/domain-list-community/raw/release/dlc.dat -O build/geosite.dat && \
    wget https://github.com/v2fly/geoip/raw/release/geoip.dat -O build/geoip.dat
# ##############################################################################


##########################################
#         构建基础镜像                    #
##########################################
# 
# 指定创建的基础镜像
FROM alpine:latest

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ

ARG PKG_DEPS="\
      tzdata \
      ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

# dumb-init
# https://github.com/Yelp/dumb-init
ARG DUMBINIT_VERSION=1.2.5
ENV DUMBINIT_VERSION=$DUMBINIT_VERSION

# http://label-schema.org/rc1/
LABEL maintainer="danxiaonuo <danxiaonuo@danxiaonuo.me>" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="$DOCKER_IMAGE" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://github.com/$DOCKER_IMAGE" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/$DOCKER_IMAGE" \
      versions.dumb-init=${DUMBINIT_VERSION}


# 修改源地址
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
# ***** 安装依赖 *****
RUN set -eux \
   # 更新源地址
   && apk update \
   # 更新系统并更新系统软件
   && apk upgrade && apk upgrade \
   && apk add -U --update $PKG_DEPS \
   # 更新时区
   && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
   # 更新时间
   && echo ${TZ} > /etc/timezone
	
# 拷贝trojan-go
COPY --from=builder /src/build/trojan-go /usr/bin/trojan-go

# 授予文件权限
RUN set -eux && \
    mkdir -p /etc/trojan-go/ /usr/share/trojan-go/ && \
    chmod +x /usr/bin/trojan-go /usr/share/trojan-go

# 拷贝配置文件
COPY --from=builder /src/example/server.json /etc/trojan-go/config.json
COPY --from=builder /src/build/geoip.dat /usr/share/trojan-go/geoip.dat
COPY --from=builder /src/build/geosite.dat /usr/share/trojan-go/geosite.dat

# 安装dumb-init
RUN set -eux \
    && wget --no-check-certificate https://github.com/Yelp/dumb-init/releases/download/v${DUMBINIT_VERSION}/dumb-init_${DUMBINIT_VERSION}_x86_64 -O /usr/bin/dumb-init \
    && chmod +x /usr/bin/dumb-init

# 容器信号处理
STOPSIGNAL SIGQUIT

# 入口
ENTRYPOINT ["dumb-init"]

# 运行trojan-go
CMD ["trojan-go", "-config", "/etc/trojan-go/config.json"]
