import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        shell: "#F3F4FA",
        ink: "#12131A",
        plum: {
          50: "#F6F1FF",
          100: "#EDE2FF",
          200: "#D7BEFF",
          300: "#C39BFF",
          400: "#A86BFF",
          500: "#8B4DFF",
          600: "#7339DE",
          700: "#5D30B4",
          800: "#482A84",
          900: "#312357",
        },
      },
      boxShadow: {
        lift: "0 20px 60px rgba(85, 57, 150, 0.12)",
        soft: "0 12px 30px rgba(20, 23, 33, 0.08)",
      },
      fontFamily: {
        sans: [
          "Satoshi",
          "Avenir Next",
          "SF Pro Display",
          "Segoe UI",
          "sans-serif",
        ],
      },
      backgroundImage: {
        "mesh-shell":
          "radial-gradient(circle at top left, rgba(166, 119, 255, 0.22), transparent 34%), radial-gradient(circle at right, rgba(115, 57, 222, 0.16), transparent 26%), linear-gradient(180deg, #f9f7ff 0%, #f4f5fb 100%)",
      },
    },
  },
  plugins: [],
};

export default config;
