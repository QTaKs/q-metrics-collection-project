#Builder
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder
COPY ./prometheus-net /prometheus-net
WORKDIR /prometheus-net/Sample.Web
RUN dotnet restore
RUN dotnet publish -c Release -o binary
#Runner
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS final
WORKDIR /prometheus-net/Sample.Web/binary
COPY --from=builder /prometheus-net /prometheus-net
# RUN echo $(grep $(hostname) /etc/hosts | cut -f1) aspnet.image >> /etc/hosts
ENTRYPOINT ["dotnet", "Sample.Web.dll"]
