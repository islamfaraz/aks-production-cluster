using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using System;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => Results.Ok(new
{
    service = "AKS Sample API",
    status = "healthy",
    version = Environment.GetEnvironmentVariable("APP_VERSION") ?? "1.0.0",
    hostname = Environment.MachineName,
    timestamp = DateTime.UtcNow
}));

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));
app.MapGet("/ready", () => Results.Ok(new { status = "ready" }));

app.Run();
