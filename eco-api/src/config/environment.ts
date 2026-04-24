import { config } from 'dotenv';

const env = process.env.NODE_ENV || 'development';
const envPath = `.env.${env}`;

config({ path: envPath });

const envVars = {
  PORT: +(process.env.PORT ?? 3000),
};

export const { PORT } = envVars
