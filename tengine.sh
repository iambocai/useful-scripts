#!/bin/bash
#
#  tengine2.1.1 安装脚本
#  Version: 1.3
#  Author: iambocai
#

DEFAULT_PATH=/home/work/bin/nginx
#安装目标目录,此目录会被传入参数覆盖
INSTALL_PATH=${1:-$DEFAULT_PATH}

#lua和nginx安装路径
NGINX_PATH=${INSTALL_PATH}
LUAJIT_PATH=${NGINX_PATH}/luajit

#脚本运行目录
WORKDIR=$(cd $(dirname $0) && pwd)
#环境配置目录
ENV=${WORKDIR}/luajit.sh


#下载和解压各包
function download_and_unpack() {
    
    test -e ${WORKDIR}/tengine-2.1.1 || wget 'http://tengine.taobao.org/download/tengine-2.1.1.tar.gz' -O tengine-2.1.1.tar.gz &&  tar -zxf tengine-2.1.1.tar.gz 
    test -e ${WORKDIR}/ngx_cache_purge-2.1 || wget 'http://labs.frickle.com/files/ngx_cache_purge-2.1.tar.gz' -O ngx_cache_purge-2.1.tar.gz && tar -zxf ngx_cache_purge-2.1.tar.gz 
    test -e ${WORKDIR}/lua-nginx-module-0.9.14 || wget 'https://github.com/openresty/lua-nginx-module/archive/v0.9.14.tar.gz' -O lua-nginx-module-0.9.14.tar.gz && tar -zxf lua-nginx-module-0.9.14.tar.gz 
    test -e ${WORKDIR}/pcre-8.36 || wget 'http://downloads.sourceforge.net/project/pcre/pcre/8.36/pcre-8.36.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fpcre%2Ffiles%2Fpcre%2F8.36%2F&ts=1392890785&use_mirror=hivelocity' -O pcre-8.36.tar.bz2 && tar -jxf pcre-8.36.tar.bz2 
    test -e ${WORKDIR}/zlib-1.2.8 || wget 'http://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz?r=http%3A%2F%2Fwww.zlib.net%2F&ts=1393245625&use_mirror=cznic' -O zlib-1.2.8.tar.gz && tar -zxf zlib-1.2.8.tar.gz
    test -e ${WORKDIR}/luajit-2.0 || git clone --branch v2.1 --progress -v "http://luajit.org/git/luajit-2.0.git" luajit-2.0 
    test -e ${WORKDIR}/lua-resty-core || git clone 'https://github.com/agentzh/lua-resty-core.git' lua-resty-core  

    test -e ${WORKDIR}/ngx_devel_kit-0.2.19 || wget 'https://github.com/simpl/ngx_devel_kit/archive/v0.2.19.tar.gz' -O ngx_devel_kit-0.2.19.tar.gz && tar -zxf ngx_devel_kit-0.2.19.tar.gz 
    test -e ${WORKDIR}/openssl-1.0.1q || wget 'https://www.openssl.org/source/openssl-1.0.1q.tar.gz' -O openssl-1.0.1q.tar.gz && tar -zxf openssl-1.0.1q.tar.gz 
    test -e ${WORKDIR}/headers-more-nginx-module-0.25 || wget 'https://github.com/agentzh/headers-more-nginx-module/archive/v0.25.tar.gz' -O headers-more-nginx-module-0.25.tar.gz && tar -zxvf headers-more-nginx-module-0.25.tar.gz 
    test -e ${WORKDIR}/nginx-upstream-fair-master || wget 'https://github.com/gnosek/nginx-upstream-fair/archive/master.zip' -O nginx-upstream-fair-master.zip && unzip -o nginx-upstream-fair-master.zip
    test -e ${WORKDIR}/nginx-module-vts || git clone 'https://github.com/iambocai/nginx-module-vts.git' nginx-module-vts
}

#luajit安装 
function install_luajit(){
    cd ${WORKDIR}
    # Install luajit
    cd ${WORKDIR}/luajit-2.0
    make clean
    #修改Makefile中的安装路径
    sed -i 's#^export PREFIX= .*$#export PREFIX= '${LUAJIT_PATH}'#g' Makefile
    make && make install

    #非stable版本没有link到luajit，需要自己ln
    ln -sf ${LUAJIT_PATH}/bin/luajit-2.1.0-alpha  ${LUAJIT_PATH}/bin/luajit

    #写个环境脚本，后面编译时需要这些环境变量
    echo -en "
export LUAJIT_LIB=${LUAJIT_PATH}/lib
export LUAJIT_INC=${LUAJIT_PATH}/include/luajit-2.1
export LD_LIBRARY_PATH=${LUAJIT_PATH}/lib:\$LD_LIBRARY_PATH
export PATH=${NGINX_PATH}/sbin:${LUAJIT_PATH}/bin:\$PATH
" > ${ENV}

    #添加环境变量
    test -f /etc/profile.d/nginx.sh && mv /etc/profile.d/nginx.sh{,.old}
    cp ${ENV} ${NGINX_PATH}/sbin/profile.nginx.sh || cat ${ENV} >> ~/.bash_profile
}

#lua_resty_core安装
function install_lua_resty_core(){
    source ${ENV}

    cd ${WORKDIR}/lua-resty-core
    sed -i 's#^PREFIX ?=          .*$#PREFIX ?=          '${LUAJIT_PATH}'#g' Makefile
    make install
}

#nginx安装
function install_tengine(){
    source ${ENV}

    cd ${WORKDIR}/tengine-2.1.1
    make clean
    CFLAGS="-O3 -fPIC" ./configure --prefix=${NGINX_PATH} \
         --with-pcre=../pcre-8.36 \
         --with-pcre-opt='-O3 -fPIC' \
         --with-pcre-jit \
         --with-zlib=../zlib-1.2.8 \
         --with-zlib-opt='-O3 -fPIC' \
         --with-openssl=../openssl-1.0.1q \
         --with-openssl-opt='-O3 -fPIC' \
         --add-module=../lua-nginx-module-0.9.14/ \
         --add-module=../ngx_cache_purge-2.1 \
         --add-module=../headers-more-nginx-module-0.25 \
         --add-module=../nginx-upstream-fair-master \
         --add-module=../ngx_devel_kit-0.2.19 \
         --add-module=../nginx-module-vts \
         --with-http_stub_status_module \
         --with-http_ssl_module \
         --with-http_realip_module \
         --with-http_gzip_static_module \
         --with-http_addition_module \
         --with-http_ssl_module \
         --with-http_upstream_session_sticky_module=shared \
         --with-http_sub_module \
         --without-mail_smtp_module \
         --without-mail_imap_module \
         --without-mail_pop3_module 
    make && make install
    mv ${ENV} ${NGINX_PATH}/sbin/
}


function info_success(){
    echo -en "
    ======================================================================
    安装完成！

    Tengine目录: $INSTALL_PATH    
      - NGINX目录: $NGINX_PATH

    启动方法：
      - nginx: cd $NGINX_PATH/sbin && source $NGINX_PATH/sbin/profile.nginx.sh && nginx 

    建议: cp $NGINX_PATH/sbin/profile.nginx.sh  /etc/profile.d/nginx.sh

    ======================================================================
    "
}

function clean_source(){
    cd ${WORKDIR}/ && \
    rm  tengine-2.1.1{,.tar.gz} \
        ngx_cache_purge-2.1{,.tar.gz} \
        lua-nginx-module-0.9.14{,.tar.gz} \
        pcre-8.36{,.tar.bz2} \
        luajit-2.0 \
        lua-resty-core \
        x-waf \
        ngx_devel_kit-0.2.19{,.tar.gz} \
        zlib-1.2.8{,.tar.gz} \
        openssl-1.0.1q{,.tar.gz} \
        headers-more-nginx-module-0.25{,.tar.gz} \
        nginx-upstream-fair-master{,.zip} \
        nginx-module-vts \
        -rf
}

main(){
#    if [ -e ${INSTALL_PATH} ]; then
#        echo "INSTALL_PATH ${INSTALL_PATH} alredy EXISTS!!"
#        exit 1
#    fi

    download_and_unpack && \
    install_luajit && \  
    install_lua_resty_core && \
    install_tengine && \
    info_success

     
#   clean_source
}

main
