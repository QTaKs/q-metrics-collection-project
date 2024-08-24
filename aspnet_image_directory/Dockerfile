#Builder
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder
COPY ./prometheus-net /prometheus-net
WORKDIR /prometheus-net/Sample.Web
RUN dotnet restore
RUN dotnet publish -c Release -o binary
#Runner
#I do not understand why works only 6.0 runner
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS final
WORKDIR /prometheus-net/Sample.Web/binary
COPY --from=builder /prometheus-net /prometheus-net
ENTRYPOINT ["dotnet", "Sample.Web.dll"]
