const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files from public directory
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// API endpoint
app.get('/api/info', (req, res) => {
  res.json({
    app: 'feijoa-app',
    message: 'Welcome to the Feijoa App - AWS EKS Demo',
    region: 'Asia Pacific (New Zealand)',
    description: 'A simple containerized application running on Amazon EKS',
    funFact: 'Feijoas are a delicious fruit native to South America but widely grown in New Zealand!'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Feijoa App is running on port ${PORT}`);
  console.log(`Health check available at http://localhost:${PORT}/health`);
  console.log(`API info available at http://localhost:${PORT}/api/info`);
});
