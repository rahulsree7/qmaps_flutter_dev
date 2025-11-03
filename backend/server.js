const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();
const PORT = 8000;

// Middleware
app.use(express.json());
app.use(cors());

// Mock user database (replace with real database)
const users = [
    {
        id: 1,
        email: 'admin@qmaps.com',
        password: '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', // password: "password"
        username: 'Admin User'
    },
    {
        id: 2,
        email: 'user@qmaps.com',
        password: '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', // password: "password"
        username: 'Test User'
    }
];

// Login endpoint
app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body;

    try {
        // Find user by email
        const user = users.find(u => u.email === email);

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials'
            });
        }

        // Verify password (in production, use bcrypt.compare)
        // For demo purposes, we'll use simple string comparison
        const isValidPassword = password === 'password'; // Simple demo

        if (!isValidPassword) {
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials'
            });
        }

        // Generate JWT token
        const token = jwt.sign(
            { userId: user.id, email: user.email },
            'your-secret-key',
            { expiresIn: '24h' }
        );

        res.json({
            success: true,
            data: {
                user_id: user.id,
                email: user.email,
                username: user.username,
                token: token,
                expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
            }
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// JWT Authentication middleware
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
        return res.status(401).json({
            success: false,
            message: 'Access token required'
        });
    }

    jwt.verify(token, 'your-secret-key', (err, user) => {
        if (err) {
            return res.status(403).json({
                success: false,
                message: 'Invalid or expired token'
            });
        }
        req.user = user;
        next();
    });
};

// Checklists endpoint (protected)
app.get('/api/auditor/checklists', authenticateToken, (req, res) => {
    // Mock checklist data
    const checklists = [
        {
            id: 76,
            title: "Duty Free - General",
            location: "TERMINAL 2 • Duty Free Departure",
            status: "ACTIVE",
            answered_total: "0/11",
            percent: 0,
            first_question: "Clean Tables?",
            due_date: "2025-09-24 13:00:00",
            next_time: "2025-09-24 14:00:00"
        },
        {
            id: 81,
            title: "F & B General",
            location: "TERMINAL 2 • Pizza Hut",
            status: "ACTIVE",
            answered_total: "0/3",
            percent: 0,
            first_question: "Table are clean?",
            due_date: "2025-09-19 13:00:00",
            next_time: "2025-09-19 14:00:00"
        },
        {
            id: 82,
            title: "F & B General",
            location: "TERMINAL 2 • KFC Gate 10",
            status: "ACTIVE",
            answered_total: "0/3",
            percent: 0,
            first_question: "Table are clean?",
            due_date: "2025-09-24 12:00:00",
            next_time: "2025-09-24 20:00:00"
        },
        {
            id: 83,
            title: "Lounges",
            location: "TERMINAL 2 • 080 Dom Lounge",
            status: "IN PROGRESS",
            answered_total: "3/3",
            percent: 100,
            first_question: "Tables are clean ?",
            due_date: "2025-09-24 12:00:00",
            next_time: "2025-09-24 12:06:00"
        },
        {
            id: 84,
            title: "Retail",
            location: "TERMINAL 2 • Relay Level 3 Checkin",
            status: "IN PROGRESS",
            answered_total: "0/3",
            percent: 0,
            first_question: "Tables are clean ?",
            due_date: "2025-09-24 12:00:00",
            next_time: "2025-09-24 15:00:00"
        },
        {
            id: 85,
            title: "Duty Free - General",
            location: "TERMINAL 2 • Duty Free Departure LMS",
            status: "ACTIVE",
            answered_total: "0/11",
            percent: 0,
            first_question: "Clean Tables?",
            due_date: "2025-09-25 12:00:00",
            next_time: "2025-09-25 12:10:00"
        }
    ];

    res.json({
        success: true,
        data: {
            checklists: checklists,
            user_role: "admin"
        }
    });
});

// Save PIN endpoint (protected)
app.post('/api/auth/save-pin', authenticateToken, (req, res) => {
    const { pin } = req.body;
    const userId = req.user.userId;

    try {
        // In a real application, you would save the PIN to the database
        // For now, we'll just simulate success
        console.log(`PIN saved for user ${userId}: ${pin}`);

        res.json({
            success: true,
            message: 'PIN saved successfully'
        });
    } catch (error) {
        console.error('Save PIN error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to save PIN'
        });
    }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({ status: 'OK', message: 'QMAPS API is running' });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 QMAPS API Server running on http://127.0.0.1:${PORT}`);
    console.log(`📋 Available endpoints:`);
    console.log(`   POST /api/auth/login`);
    console.log(`   POST /api/auth/save-pin (requires auth)`);
    console.log(`   GET  /api/auditor/checklists (requires auth)`);
    console.log(`   GET  /api/health`);
    console.log(`\n🔐 Test credentials:`);
    console.log(`   Email: admin@qmaps.com, Password: password`);
    console.log(`   Email: user@qmaps.com, Password: password`);
});
