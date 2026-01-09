const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const session = require("express-session");
const MongoStore = require("connect-mongo");
const rateLimit = require("express-rate-limit");
const helmet = require("helmet");
const validator = require("validator");
const crypto = require("crypto");
const cors = require("cors");
const bodyParser = require("body-parser");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const app = express();

// Security middleware
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'", "https://unpkg.com"],
        scriptSrcAttr: ["'unsafe-inline'"],
        styleSrc: [
          "'self'",
          "'unsafe-inline'",
          "https://fonts.googleapis.com",
          "https://cdn.jsdelivr.net",
          "https://unpkg.com",
        ],
        fontSrc: [
          "'self'",
          "https://fonts.gstatic.com",
          "https://cdn.jsdelivr.net",
        ],
        imgSrc: ["'self'", "data:", "https:"],
        mediaSrc: ["'self'", "data:"],
        connectSrc: ["'self'", "http://localhost:5000", "http://localhost:5001", "http://127.0.0.1:5000", "http://127.0.0.1:5001", "https://unpkg.com"],
        frameSrc: ["'self'"],
        objectSrc: ["'none'"],
        upgradeInsecureRequests: [],
      },
    },
  })
);
app.use(
  cors({
    origin:
      process.env.NODE_ENV === "production"
        ? ["https://yourdomain.com"]
        : [
            "http://localhost:3000",
            "http://localhost:5000",
            "http://127.0.0.1:5000",
            "http://127.0.0.1:5500",
          ],
    credentials: true,
  })
);

// Rate limiting
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 50, // limit each IP to 50 requests per windowMs (increased for testing)
  message: {
    success: false,
    message: "Too many authentication attempts, please try again later.",
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
});

// Temporarily disabled rate limiting for testing
// app.use("/login", authLimiter);
// app.use("/signup", authLimiter);
// app.use(generalLimiter);

// Health check endpoint (very first route)
app.get("/api/health", (req, res) => {
  res.json({ status: "healthy", service: "Node.js Server" });
});

// Body parsing middleware
app.use(bodyParser.json({ limit: "10mb" }));
app.use(bodyParser.urlencoded({ extended: true, limit: "10mb" }));

// Session configuration
const SESSION_IDLE_MS = Number(process.env.SESSION_IDLE_MS || process.env.SESSION_MAX_AGE || 15 * 60 * 1000); // default 15m
const SESSION_ABSOLUTE_MS = Number(process.env.SESSION_ABSOLUTE_MS || 60 * 60 * 1000); // default 60m absolute cap

app.use(
  session({
    secret:
      process.env.SESSION_SECRET ||
      "baganetic-super-secret-key-change-in-production",
    resave: false,
    saveUninitialized: false,
    rolling: true, // refresh idle expiry on activity
    store: MongoStore.create({
      mongoUrl: "mongodb://127.0.0.1:27017/baganetic_users",
      touchAfter: 24 * 3600, // lazy session update
    }),
    cookie: {
      secure: process.env.NODE_ENV === "production",
      httpOnly: true,
      maxAge: SESSION_IDLE_MS,
      sameSite: "lax",
    },
  })
);

// Enforce idle and absolute session timeouts
app.use((req, res, next) => {
  try {
    // Only enforce for API/authenticated flows; let static assets pass
    const url = req.path || "";
    const isApi = url.startsWith("/api/") || ["/me", "/profile", "/login", "/logout", "/signup"].includes(url);

    if (!isApi) return next();

    const now = Date.now();
    if (!req.session.__createdAt) {
      req.session.__createdAt = now;
      req.session.__lastSeenAt = now;
    }

    const lastSeen = req.session.__lastSeenAt || now;
    const absoluteAge = now - (req.session.__createdAt || now);
    const idleAge = now - lastSeen;

    const idleExpired = idleAge > SESSION_IDLE_MS;
    const absoluteExpired = absoluteAge > SESSION_ABSOLUTE_MS;

    if (idleExpired || absoluteExpired) {
      // Destroy session and respond 401
      req.session.destroy(() => {
        res.status(401).json({ success: false, message: "Session expired. Please log in again." });
      });
      return;
    }

    // Update last seen for sliding idle timeout
    req.session.__lastSeenAt = now;
  } catch (e) {
    // Non-blocking on errors
  }
  next();
});

// MongoDB connection
mongoose
  .connect("mongodb://127.0.0.1:27017/baganetic_users", {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log("✅ MongoDB connected"))
  .catch((err) => console.error(err));

// User Schema
const userSchema = new mongoose.Schema(
  {
    username: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      minlength: 3,
      maxlength: 30,
      match: /^[a-zA-Z0-9_]+$/,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      validate: [validator.isEmail, "Invalid email address"],
    },
    password: {
      type: String,
      required: true,
      minlength: 8,
    },
    fullName: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    isEmailVerified: {
      type: Boolean,
      default: false,
    },
    isAdminVerified: {
      type: Boolean,
      default: false,
    },
    verifiedAt: Date,
    verifiedBy: String,
    emailVerificationToken: String,
    emailVerificationExpires: Date,
    passwordResetToken: String,
    passwordResetExpires: Date,
    loginAttempts: {
      type: Number,
      default: 0,
    },
    lockUntil: Date,
    lastLogin: Date,
    profile: {
      avatar: String,
      bio: String,
      preferences: {
        language: { type: String, default: "en" },
        theme: { type: String, default: "light" },
        emailNotifications: { type: Boolean, default: true },
      },
      visitedPagodas: [String],
      favoritePagodas: [String],
    },
    role: {
      type: String,
      enum: ["user", "admin"],
      default: "user",
    },
  },
  {
    timestamps: true,
  }
);

// Virtual for checking if account is locked
userSchema.virtual("isLocked").get(function () {
  return !!(this.lockUntil && this.lockUntil > Date.now());
});

// Pre-save middleware to hash password
userSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();

  try {
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Method to compare password
userSchema.methods.comparePassword = async function (candidatePassword) {
  if (this.isLocked) {
    throw new Error(
      "Account is temporarily locked due to too many failed login attempts"
    );
  }

  const isMatch = await bcrypt.compare(candidatePassword, this.password);

  if (!isMatch) {
    this.loginAttempts += 1;

    // Lock account after 5 failed attempts for 2 hours
    if (this.loginAttempts >= 5) {
      this.lockUntil = Date.now() + 2 * 60 * 60 * 1000; // 2 hours
    }

    await this.save();
    return false;
  }

  // Reset login attempts on successful login
  if (this.loginAttempts > 0) {
    this.loginAttempts = 0;
    this.lockUntil = undefined;
    this.lastLogin = new Date();
    await this.save();
  }

  return true;
};

// Method to generate email verification token
userSchema.methods.generateEmailVerificationToken = function () {
  this.emailVerificationToken = crypto.randomBytes(32).toString("hex");
  this.emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000; // 24 hours
  return this.emailVerificationToken;
};

// Method to generate password reset token
userSchema.methods.generatePasswordResetToken = function () {
  this.passwordResetToken = crypto.randomBytes(32).toString("hex");
  this.passwordResetExpires = Date.now() + 10 * 60 * 1000; // 10 minutes
  return this.passwordResetToken;
};

const User = mongoose.model("User", userSchema);

// Pagoda Schema
const pagodaSchema = new mongoose.Schema({
  id: { type: String, unique: true, required: true },
  name: { type: String, required: true },
  shortName: String,
  type: String,
  location: {
    city: String,
    region: String,
    country: String,
    coordinates: {
      lat: Number,
      lng: Number,
    },
  },
  images: {
    main: String,
    gallery: [String],
    thumbnail: String,
  },
  description: {
    short: String,
    long: String,
  },
  history: {
    built: String,
    dynasty: String,
    king: String,
    architect: String,
    renovations: [String],
  },
  architecture: {
    style: String,
    height: String,
    structure: String,
    materials: [String],
    features: [String],
  },
  religious: {
    significance: String,
    buddha_statues: Number,
    main_deity: String,
    festivals: [String],
  },
  visiting: {
    entrance_fee: String,
    opening_hours: String,
    best_time: String,
    duration: String,
    accessibility: String,
  },
  tags: [String],
  status: String,
  featured: { type: Boolean, default: false },
  distances: { type: Map, of: Number },
});

const Pagoda = mongoose.model("Pagoda", pagodaSchema);

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = "assets/images/avatars";
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, "avatar-" + uniqueSuffix + path.extname(file.originalname));
  },
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: function (req, file, cb) {
    const allowedTypes = /jpeg|jpg|png|gif|webp/;
    const extname = allowedTypes.test(
      path.extname(file.originalname).toLowerCase()
    );
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error("Only image files are allowed!"));
    }
  },
});

// Serve static files (frontend)
app.use(express.static("."));

// Proxy to Flask A* API
const { createProxyMiddleware } = require("http-proxy-middleware");

// Proxy pathfinding requests to Flask server
app.use(
  "/api/pathfinder",
  createProxyMiddleware({
    target: "http://localhost:5000",
    changeOrigin: true,
    pathRewrite: {
      "^/api/pathfinder": "/api/pathfinder",
    },
  })
);

// Proxy pagoda data requests to Flask server
app.use(
  "/api/pagodas",
  createProxyMiddleware({
    target: "http://localhost:5000",
    changeOrigin: true,
  })
);

// JWT secret
const JWT_SECRET =
  process.env.JWT_SECRET || "baganetic-jwt-secret-change-in-production";
const JWT_EXPIRES_IN_SECONDS = Number(process.env.JWT_EXPIRES_IN || Math.floor(SESSION_ABSOLUTE_MS / 1000) || 3600);

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res
      .status(401)
      .json({ success: false, message: "Access token required" });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res
        .status(403)
        .json({ success: false, message: "Invalid or expired token" });
    }
    req.user = user;
    next();
  });
};

// Password strength validation
const validatePasswordStrength = (password) => {
  const minLength = 8;
  const hasUpperCase = /[A-Z]/.test(password);
  const hasLowerCase = /[a-z]/.test(password);
  const hasNumbers = /\d/.test(password);
  const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);

  const errors = [];

  if (password.length < minLength) {
    errors.push(`Password must be at least ${minLength} characters long`);
  }
  if (!hasUpperCase) {
    errors.push("Password must contain at least one uppercase letter");
  }
  if (!hasLowerCase) {
    errors.push("Password must contain at least one lowercase letter");
  }
  if (!hasNumbers) {
    errors.push("Password must contain at least one number");
  }
  if (!hasSpecialChar) {
    errors.push("Password must contain at least one special character");
  }

  return {
    isValid: errors.length === 0,
    errors: errors,
    strength: calculatePasswordStrength(password),
  };
};

const calculatePasswordStrength = (password) => {
  let score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (/[A-Z]/.test(password)) score++;
  if (/[a-z]/.test(password)) score++;
  if (/\d/.test(password)) score++;
  if (/[!@#$%^&*(),.?":{}|<>]/.test(password)) score++;
  if (password.length >= 16) score++;

  if (score <= 2) return "weak";
  if (score <= 4) return "medium";
  return "strong";
};

// User routes
app.post("/signup", async (req, res) => {
  try {
    const { username, email, password, fullName } = req.body;

    // Input validation
    if (!username || !email || !password || !fullName) {
      return res.status(400).json({
        success: false,
        message: "All fields are required",
      });
    }

    // Validate email format
    if (!validator.isEmail(email)) {
      return res.status(400).json({
        success: false,
        message: "Invalid email format",
      });
    }

    // Validate username format
    if (
      !/^[a-zA-Z0-9_]+$/.test(username) ||
      username.length < 3 ||
      username.length > 30
    ) {
      return res.status(400).json({
        success: false,
        message:
          "Username must be 3-30 characters and contain only letters, numbers, and underscores",
      });
    }

    // Validate password strength
    const passwordValidation = validatePasswordStrength(password);
    if (!passwordValidation.isValid) {
      return res.status(400).json({
        success: false,
        message: "Password does not meet requirements",
        errors: passwordValidation.errors,
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({
      $or: [{ email: email.toLowerCase() }, { username }],
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message:
          existingUser.email === email.toLowerCase()
            ? "Email already registered"
            : "Username already taken",
      });
    }

    // Create new user
    const newUser = new User({
      username,
      email: email.toLowerCase(),
      password, // Will be hashed by pre-save middleware
      fullName: fullName.trim(),
      isAdminVerified: false, // Default to unverified, admin will verify
      profile: {
        favoritePagodas: [],
        visitedPagodas: [],
        avatar: "default",
        bio: "",
        preferences: {
          language: "en",
          theme: "light",
        },
      },
    });

    // Generate email verification token
    const verificationToken = newUser.generateEmailVerificationToken();

    await newUser.save();

    // Generate JWT token (aligned to absolute session timeout)
    const token = jwt.sign(
      {
        userId: newUser._id,
        username: newUser.username,
        email: newUser.email,
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN_SECONDS }
    );

    // Store user session
    req.session.userId = newUser._id;

    res.status(201).json({
      success: true,
      message:
        "Account created successfully! Your account is pending admin verification.",
      token,
      user: {
        id: newUser._id,
        username: newUser.username,
        email: newUser.email,
        fullName: newUser.fullName,
        isEmailVerified: newUser.isEmailVerified,
        isAdminVerified: newUser.isAdminVerified || false,
        role: newUser.role || 'user',
      },
    });
  } catch (error) {
    console.error("Signup error:", error);

    if (error.code === 11000) {
      const field = Object.keys(error.keyPattern)[0];
      return res.status(400).json({
        success: false,
        message: `${
          field.charAt(0).toUpperCase() + field.slice(1)
        } already exists`,
      });
    }

    res.status(500).json({
      success: false,
      message: "Internal server error. Please try again.",
    });
  }
});

app.post("/login", async (req, res) => {
  try {
    const { username, password } = req.body;

    // Input validation
    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: "Username and password are required",
      });
    }

    // Find user by username or email
    const user = await User.findOne({
      $or: [{ username }, { email: username.toLowerCase() }],
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    // Check if account is locked
    if (user.isLocked) {
      return res.status(423).json({
        success: false,
        message:
          "Account is temporarily locked due to too many failed login attempts. Please try again later.",
      });
    }

    // Compare password using the schema method
    try {
      const isMatch = await user.comparePassword(password);

      if (!isMatch) {
        return res.status(401).json({
          success: false,
          message: "Invalid credentials",
        });
      }

    // Generate JWT token (aligned to absolute session timeout)
    const token = jwt.sign(
        {
          userId: user._id,
          username: user.username,
          email: user.email,
        },
        JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN_SECONDS }
      );

      // Store user session
      req.session.userId = user._id;

      // Update last login
      user.lastLogin = new Date();
      await user.save();

      res.json({
        success: true,
        message: "Login successful",
        token,
        user: {
          id: user._id,
          username: user.username,
          email: user.email,
          fullName: user.fullName,
          isEmailVerified: user.isEmailVerified,
          isAdminVerified: user.isAdminVerified || false,
          role: user.role || 'user',
          lastLogin: user.lastLogin,
        },
      });
    } catch (lockError) {
      return res.status(423).json({
        success: false,
        message: lockError.message,
      });
    }
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error. Please try again.",
    });
  }
});

app.post("/logout", async (req, res) => {
  try {
    // Destroy session
    req.session.destroy((err) => {
      if (err) {
        console.error("Session destruction error:", err);
      }
    });

    res.json({ success: true, message: "Logout successful" });
  } catch (error) {
    res.status(500).json({ success: false, message: "Logout failed", error });
  }
});

// Return current authenticated user profile
app.get("/me", async (req, res) => {
  try {
    const authHeader = req.headers.authorization || "";
    const bearerToken = authHeader.startsWith("Bearer ")
      ? authHeader.slice(7)
      : null;
    const token = bearerToken || req.query.token || null;

    if (!token) {
      return res.status(401).json({ authenticated: false, message: "Missing token" });
    }

    let payload;
    try {
      payload = jwt.verify(token, JWT_SECRET);
    } catch (e) {
      return res.status(401).json({ authenticated: false, message: "Invalid token" });
    }

    const user = await User.findById(payload.userId).lean();
    if (!user) {
      return res.status(404).json({ authenticated: false, message: "User not found" });
    }

    return res.json({
      authenticated: true,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        fullName: user.fullName || "",
        isEmailVerified: !!user.isEmailVerified,
        isAdminVerified: !!user.isAdminVerified,
        role: user.role || "user",
        lastLogin: user.lastLogin || null,
        profile: { avatar: (user.profile && user.profile.avatar) || "" },
      },
    });
  } catch (error) {
    console.error("/me error:", error);
    res.status(500).json({ authenticated: false, message: "Internal error" });
  }
});

// Password reset request
app.post("/forgot-password", async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || !validator.isEmail(email)) {
      return res.status(400).json({
        success: false,
        message: "Valid email address is required",
      });
    }

    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      // Don't reveal if email exists for security
      return res.json({
        success: true,
        message:
          "If an account with that email exists, we've sent a password reset link.",
      });
    }

    // Generate password reset token
    const resetToken = user.generatePasswordResetToken();
    await user.save();

    // In production, send email here
    console.log(`Password reset token for ${email}: ${resetToken}`);

    res.json({
      success: true,
      message:
        "If an account with that email exists, we've sent a password reset link.",
      // Remove this in production
      resetToken: resetToken,
    });
  } catch (error) {
    console.error("Forgot password error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error. Please try again.",
    });
  }
});

// Reset password
app.post("/reset-password", async (req, res) => {
  try {
    const { token, newPassword } = req.body;

    if (!token || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Token and new password are required",
      });
    }

    // Validate password strength
    const passwordValidation = validatePasswordStrength(newPassword);
    if (!passwordValidation.isValid) {
      return res.status(400).json({
        success: false,
        message: "Password does not meet requirements",
        errors: passwordValidation.errors,
      });
    }

    const user = await User.findOne({
      passwordResetToken: token,
      passwordResetExpires: { $gt: Date.now() },
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired reset token",
      });
    }

    // Update password
    user.password = newPassword; // Will be hashed by pre-save middleware
    user.passwordResetToken = undefined;
    user.passwordResetExpires = undefined;
    user.loginAttempts = 0;
    user.lockUntil = undefined;

    await user.save();

    res.json({
      success: true,
      message:
        "Password reset successful. You can now log in with your new password.",
    });
  } catch (error) {
    console.error("Reset password error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error. Please try again.",
    });
  }
});

// Get user profile
app.get("/profile", authenticateToken, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select(
      "-password -passwordResetToken -emailVerificationToken"
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.json({
      success: true,
      user: user,
    });
  } catch (error) {
    console.error("Get profile error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
});

// Update user profile
app.put("/profile", authenticateToken, async (req, res) => {
  try {
    const { fullName, bio, preferences, location, website, interests } = req.body;
    const userId = req.user.userId;

    const updateData = {};

    if (fullName !== undefined) {
      if (!fullName.trim() || fullName.length > 100) {
        return res.status(400).json({
          success: false,
          message: "Full name must be 1-100 characters",
        });
      }
      updateData.fullName = fullName.trim();
    }

    if (bio !== undefined) {
      if (bio.length > 500) {
        return res.status(400).json({
          success: false,
          message: "Bio must be less than 500 characters",
        });
      }
      updateData["profile.bio"] = bio.trim();
    }

    if (preferences) {
      if (preferences.language) {
        updateData["profile.preferences.language"] = preferences.language;
      }
      if (preferences.theme) {
        updateData["profile.preferences.theme"] = preferences.theme;
      }
      if (preferences.emailNotifications !== undefined) {
        updateData["profile.preferences.emailNotifications"] =
          preferences.emailNotifications;
      }
    }

    // Optional extended fields
    if (location !== undefined) {
      updateData["profile.location"] = String(location || "").trim();
    }
    if (website !== undefined) {
      updateData["profile.website"] = String(website || "").trim();
    }
    if (Array.isArray(interests)) {
      updateData["profile.interests"] = interests
        .map((i) => String(i).trim())
        .filter((i) => i);
    }

    const user = await User.findByIdAndUpdate(userId, updateData, {
      new: true,
      runValidators: true,
    }).select("-password -passwordResetToken -emailVerificationToken");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.json({
      success: true,
      message: "Profile updated successfully",
      user: user,
    });
  } catch (error) {
    console.error("Update profile error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
});

// Upload profile picture
app.post(
  "/profile/avatar",
  authenticateToken,
  upload.single("avatar"),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: "No file uploaded",
        });
      }

      const userId = req.user.userId;
      const user = await User.findById(userId);

      if (!user) {
        // Delete uploaded file if user not found
        fs.unlinkSync(req.file.path);
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      // Delete old avatar if exists
      if (user.profile.avatar && user.profile.avatar !== "default") {
        const oldAvatarPath = path.join(
          "assets/images/avatars",
          path.basename(user.profile.avatar)
        );
        if (fs.existsSync(oldAvatarPath)) {
          fs.unlinkSync(oldAvatarPath);
        }
      }

      // Update user's avatar path
      user.profile.avatar = `/assets/images/avatars/${req.file.filename}`;
      await user.save();

      res.json({
        success: true,
        message: "Profile picture updated successfully",
        avatar: user.profile.avatar,
      });
    } catch (error) {
      console.error("Avatar upload error:", error);

      // Delete uploaded file on error
      if (req.file && fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }

      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  }
);

// Change password
app.put("/profile/password", authenticateToken, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.userId;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Current password and new password are required",
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // Verify current password
    const isCurrentPasswordValid = await user.comparePassword(currentPassword);
    if (!isCurrentPasswordValid) {
      return res.status(400).json({
        success: false,
        message: "Current password is incorrect",
      });
    }

    // Validate new password strength
    const passwordValidation = validatePasswordStrength(newPassword);
    if (!passwordValidation.isValid) {
      return res.status(400).json({
        success: false,
        message: "Password does not meet requirements",
        errors: passwordValidation.errors,
      });
    }

    // Update password
    user.password = newPassword;
    await user.save();

    res.json({
      success: true,
      message: "Password changed successfully",
    });
  } catch (error) {
    console.error("Change password error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
});

// Delete account
app.delete("/profile", authenticateToken, async (req, res) => {
  try {
    const { password } = req.body;
    const userId = req.user.userId;

    if (!password) {
      return res.status(400).json({
        success: false,
        message: "Password is required to delete account",
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // Verify password
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(400).json({
        success: false,
        message: "Password is incorrect",
      });
    }

    // Delete user's avatar if exists
    if (user.profile.avatar && user.profile.avatar !== "default") {
      const avatarPath = path.join(
        "assets/images/avatars",
        path.basename(user.profile.avatar)
      );
      if (fs.existsSync(avatarPath)) {
        fs.unlinkSync(avatarPath);
      }
    }

    // Delete user account
    await User.findByIdAndDelete(userId);

    res.json({
      success: true,
      message: "Account deleted successfully",
    });
  } catch (error) {
    console.error("Delete account error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
});

// Get user favorites
app.get("/api/user/favorites", authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const user = await User.findById(userId).select("profile.favoritePagodas");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const favoriteIds = user.profile.favoritePagodas || [];
    const favorites = await Pagoda.find({ id: { $in: favoriteIds } });

    res.json(favorites);
  } catch (error) {
    console.error("Get favorites error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
});

// Add pagoda to favorites
app.post(
  "/api/user/favorites/:pagodaId",
  authenticateToken,
  async (req, res) => {
    try {
      const { pagodaId } = req.params;
      const userId = req.user.userId;

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      // Check if pagoda exists
      const pagoda = await Pagoda.findOne({ id: pagodaId });
      if (!pagoda) {
        return res.status(404).json({
          success: false,
          message: "Pagoda not found",
        });
      }

      if (!user.profile.favoritePagodas.includes(pagodaId)) {
        user.profile.favoritePagodas.push(pagodaId);
        await user.save();
      }

      res.json({
        success: true,
        message: "Pagoda added to favorites",
        favorites: user.profile.favoritePagodas,
      });
    } catch (error) {
      console.error("Add favorite error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  }
);

// Remove pagoda from favorites
app.delete(
  "/api/user/favorites/:pagodaId",
  authenticateToken,
  async (req, res) => {
    try {
      const { pagodaId } = req.params;
      const userId = req.user.userId;

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      user.profile.favoritePagodas = user.profile.favoritePagodas.filter(
        (id) => id !== pagodaId
      );
      await user.save();

      res.json({
        success: true,
        message: "Pagoda removed from favorites",
        favorites: user.profile.favoritePagodas,
      });
    } catch (error) {
      console.error("Remove favorite error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  }
);

// Get user visited pagodas
app.get("/api/user/visited", authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const user = await User.findById(userId).select("profile.visitedPagodas");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // Initialize visitedPagodas if it doesn't exist
    if (!user.profile.visitedPagodas) {
      user.profile.visitedPagodas = [];
      await user.save();
    }

    const visitedIds = user.profile.visitedPagodas || [];
    const visited = await Pagoda.find({ id: { $in: visitedIds } });

    res.json(visited);
  } catch (error) {
    console.error("Get visited error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
});

// Add pagoda to visited
app.post(
  "/api/user/visited/:pagodaId",
  authenticateToken,
  async (req, res) => {
    try {
      const { pagodaId } = req.params;
      const userId = req.user.userId;

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      // Initialize visitedPagodas if it doesn't exist
      if (!user.profile.visitedPagodas) {
        user.profile.visitedPagodas = [];
      }

      // Check if pagoda exists
      const pagoda = await Pagoda.findOne({ id: pagodaId });
      if (!pagoda) {
        return res.status(404).json({
          success: false,
          message: "Pagoda not found",
        });
      }

      if (!user.profile.visitedPagodas.includes(pagodaId)) {
        user.profile.visitedPagodas.push(pagodaId);
        await user.save();
      }

      res.json({
        success: true,
        message: "Pagoda marked as visited",
        visited: user.profile.visitedPagodas,
      });
    } catch (error) {
      console.error("Add visited error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  }
);

// Remove pagoda from visited
app.delete(
  "/api/user/visited/:pagodaId",
  authenticateToken,
  async (req, res) => {
    try {
      const { pagodaId } = req.params;
      const userId = req.user.userId;

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      // Initialize visitedPagodas if it doesn't exist
      if (!user.profile.visitedPagodas) {
        user.profile.visitedPagodas = [];
      }

      user.profile.visitedPagodas = user.profile.visitedPagodas.filter(
        (id) => id !== pagodaId
      );
      await user.save();

      res.json({
        success: true,
        message: "Pagoda removed from visited list",
        visited: user.profile.visitedPagodas,
      });
    } catch (error) {
      console.error("Remove visited error:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
      });
    }
  }
);

// Pagoda API routes
app.get("/api/pagodas", async (req, res) => {
  try {
    const pagodas = await Pagoda.find({});
    res.json({ success: true, data: pagodas });
  } catch (error) {
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch pagodas", error });
  }
});

app.get("/api/pagodas/:id", async (req, res) => {
  try {
    const pagoda = await Pagoda.findOne({ id: req.params.id });
    if (!pagoda) {
      return res
        .status(404)
        .json({ success: false, message: "Pagoda not found" });
    }
    res.json({ success: true, data: pagoda });
  } catch (error) {
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch pagoda", error });
  }
});

app.get("/api/pagodas/featured", async (req, res) => {
  try {
    const featuredPagodas = await Pagoda.find({ featured: true });
    res.json({ success: true, data: featuredPagodas });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Failed to fetch featured pagodas",
      error,
    });
  }
});

app.get("/api/pagodas/search/:query", async (req, res) => {
  try {
    const query = req.params.query;
    const searchResults = await Pagoda.find({
      $or: [
        { name: { $regex: query, $options: "i" } },
        { shortName: { $regex: query, $options: "i" } },
        { "description.short": { $regex: query, $options: "i" } },
        { "description.long": { $regex: query, $options: "i" } },
        { tags: { $in: [new RegExp(query, "i")] } },
      ],
    });
    res.json({ success: true, data: searchResults });
  } catch (error) {
    res.status(500).json({ success: false, message: "Search failed", error });
  }
});

app.get("/api/pagodas/type/:type", async (req, res) => {
  try {
    const type = req.params.type;
    const pagodas = await Pagoda.find({
      type: { $regex: type, $options: "i" },
    });
    res.json({ success: true, data: pagodas });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Failed to fetch pagodas by type",
      error,
    });
  }
});

// Start server
app.listen(3000, () =>
  console.log("🚀 Server running on http://localhost:3000")
);
