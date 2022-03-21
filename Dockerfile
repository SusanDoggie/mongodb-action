FROM docker:stable
WORKDIR /worker
COPY start-mongodb.sh .
ENTRYPOINT ["./start-mongodb.sh"]
