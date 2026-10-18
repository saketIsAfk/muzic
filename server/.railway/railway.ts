import { defineRailway, github, postgres, preserve, project, service, volume } from "railway/iac";

export default defineRailway(() => {
  const Postgres = postgres("Postgres", { region: "sfo" });
  Postgres.networking = { privateNetworkEndpoint: "postgres" };
  const postgresVolume = volume("postgres-volume", { alerts: { usage: { "100": {}, "80": {}, "95": {} } }, allowOnlineResize: true, region: "sfo", sizeMB: 500 });
  const muzicServer = service("muzic-server", {
    source: github("Saket5629/muzic", { branch: "main", rootDirectory: "server" }),
    preDeploy: "alembic upgrade head",
    replicas: { "sfo": 1 },
    env: { CLOUDINARY_API_KEY: preserve(), CLOUDINARY_API_SECRET: preserve(), CLOUDINARY_CLOUD_NAME: preserve(), CLOUDINARY_URL: preserve(), DATABASE_URL: preserve(), FIREBASE_SERVICE_ACCOUNT_JSON: preserve() },
  });

  return project("amusing-charm", {
    resources: [muzicServer, Postgres, postgresVolume],
  });
});
