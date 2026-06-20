import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'jaivowyugisxmctqesek.supabase.co',
      },
    ],
  },
};

export default nextConfig;
