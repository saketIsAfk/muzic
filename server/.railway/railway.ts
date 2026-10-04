import { defineRailway, postgres, preserve, project, service, volume } from "railway/iac";

export default defineRailway(() => {
  const Postgres = postgres("Postgres", { region: "sfo" });
  Postgres.networking = { privateNetworkEndpoint: "postgres" };
  const postgresVolume = volume("postgres-volume", { alerts: { usage: { "100": {}, "80": {}, "95": {} } }, allowOnlineResize: true, region: "sfo", sizeMB: 500 });
  const muzicServer = service("muzic-server", {
    replicas: { "sfo": 1 },
    env: { CLOUDINARY_API_KEY: preserve(), CLOUDINARY_API_SECRET: preserve(), CLOUDINARY_CLOUD_NAME: preserve(), CLOUDINARY_URL: preserve(), DATABASE_URL: preserve() },
    preDeploy: "alembic upgrade head",
  });

  return project("amusing-charm", {
    resources: [muzicServer, Postgres, postgresVolume],
  });
});
