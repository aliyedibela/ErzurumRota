FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY ["WebAPI/TaxiSignalRBackend.WebAPI/TaxiSignalRBackend.WebAPI.csproj", "WebAPI/TaxiSignalRBackend.WebAPI/"]
RUN dotnet restore "WebAPI/TaxiSignalRBackend.WebAPI/TaxiSignalRBackend.WebAPI.csproj"

COPY . .
WORKDIR "/src/WebAPI/TaxiSignalRBackend.WebAPI"
RUN dotnet publish "TaxiSignalRBackend.WebAPI.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_ENVIRONMENT=Production

EXPOSE 8080

CMD ["dotnet", "TaxiSignalRBackend.WebAPI.dll"]
