/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: {
          50: "#fff9df",
          100: "#ffef9d",
          500: "#f7c313",
          600: "#d99a00",
          700: "#aa7400",
          900: "#332100"
        },
        accent: {
          100: "#fff0bd",
          500: "#ffb000",
          600: "#d88900"
        }
      },
      boxShadow: {
        court: "0 22px 70px -36px rgba(247, 195, 19, 0.65)"
      }
    }
  },
  plugins: []
};
