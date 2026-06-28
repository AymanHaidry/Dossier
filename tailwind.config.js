/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#EEF1FF', 100: '#D9DFFF', 200: '#BCC4FF', 300: '#8E9FFF',
          400: '#5B70FF', 500: '#4C6FFF', 600: '#3A4FF0', 700: '#2D3CD6',
          800: '#2834AE', 900: '#273089',
        },
        accent: {
          50: '#FFF0F3', 100: '#FFD6DE', 200: '#FFAABB', 300: '#FF7B95',
          400: '#FF4D73', 500: '#FF6584', 600: '#F63A5E', 700: '#D6264B',
          800: '#B02240', 900: '#91233C',
        },
        mint: {
          50: '#EDFFF8', 100: '#D5FFED', 200: '#AEFFDA', 300: '#70FFBF',
          400: '#2BF59E', 500: '#43D9AD', 600: '#18B48A', 700: '#148F70',
          800: '#15715B', 900: '#145D4C',
        },
        amber: {
          50: '#FFF9EB', 100: '#FFEEC7', 200: '#FFDD8A', 300: '#FFC84D',
          400: '#FFB946', 500: '#FF9F1C', 600: '#E07D0B', 700: '#B85D0C',
          800: '#954912', 900: '#793C14',
        },
        surface: '#F5F7FF',
        ink: '#1A1D2E',
        muted: '#6B7194',
      },
      fontFamily: {
        sans: ['Nunito', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        soft: '0 2px 15px -3px rgba(76, 111, 255, 0.1), 0 4px 6px -4px rgba(76, 111, 255, 0.05)',
        card: '0 4px 20px -4px rgba(76, 111, 255, 0.12)',
        button: '0 4px 14px -3px rgba(76, 111, 255, 0.35)',
        'button-accent': '0 4px 14px -3px rgba(255, 101, 132, 0.35)',
        'button-mint': '0 4px 14px -3px rgba(67, 217, 173, 0.35)',
      },
      borderRadius: {
        '2.5xl': '1.25rem',
      },
    },
  },
  plugins: [],
}
