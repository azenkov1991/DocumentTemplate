ARG IMAGE=intersystems/iris:2019.1.0S.111.0
ARG IMAGE=store/intersystems/iris:2019.1.0.511.0-community
ARG IMAGE=store/intersystems/iris:2019.2.0.107.0-community
#ARG IMAGE=intersystems/iris:2019.3.0.302.0
ARG IMAGE=store/intersystems/iris-community:2019.3.0.309.0
FROM $IMAGE

USER root

RUN apt-get update \
    && apt-get install zip -y --no-install-recommends \
    && apt-get install unzip -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/app
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/app

USER irisowner

COPY  ./Installer.cls ./
COPY  ./src ./src
#COPY --chown=irisowner ./src/dfi ./src/dfi



RUN iris start $ISC_PACKAGE_INSTANCENAME quietly && \
    /bin/echo -e \
            "zn \"%SYS\"\n" \
            " Do ##class(Security.Users).UnExpireUserPasswords(\"*\")\n" \
            "zn \"USER\"\n" \
            " Do \$system.OBJ.Load(\"/opt/app/Installer.cls\",\"ck\")\n" \
            " Set sc = ##class(App.Installer).setup(, 3)\n" \
            " If 'sc do \$zu(4, \$JOB, 1)\n" \
            " set ^DocumentTemplateSettings(\"workingDirectory\")=\"/iris/app/Results\"" \
            " set ^DocumentTemplateSettings(\"zipCommand\")=\"zip -r -u -q \$Fullfilename ./*\"" \
            " set ^DocumentTemplateSettings(\"unzipCommand\")=\"unzip -u -q -d \$Directory  \$Fullfilename \"" \
            " halt" \
    | iris session $ISC_PACKAGE_INSTANCENAME && \
    /bin/echo -e "sys\nsys\n" \
    | iris stop $ISC_PACKAGE_INSTANCENAME quietly

CMD [ "-l", "/usr/irissys/mgr/messages.log" ]