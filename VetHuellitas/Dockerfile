FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY VetHuellitas.csproj ./
RUN dotnet restore VetHuellitas.csproj

COPY . ./
RUN dotnet publish VetHuellitas.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish ./

ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_HTTP_PORTS=8080
ENV WEBSITES_PORT=8080
EXPOSE 8080

# Respeta el puerto que asigne el proveedor (Render, Koyeb, Fly, etc.).
ENTRYPOINT ["sh", "-c", "dotnet VetHuellitas.dll --urls http://0.0.0.0:${PORT:-8080}"]
