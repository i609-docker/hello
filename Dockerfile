FROM docker.io/library/gcc:15 AS build
COPY ./hello.c /src/
WORKDIR /src/
RUN gcc -static -o hello hello.c

FROM scratch AS prod
COPY --from=build /src/hello /bin/hello
ENTRYPOINT [ "/bin/hello" ]
CMD [ "USMB" ]
