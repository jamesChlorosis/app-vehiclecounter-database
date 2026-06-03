import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { config } from "../config.js";

export function login(req: Request, res: Response) {
  const { email, password } = req.body || {};
  if (String(email || config.adminEmail) !== config.adminEmail || String(password || "") !== config.adminPassword) {
    return res.status(401).json({ error: "Invalid credentials." });
  }

  const token = jwt.sign({ sub: config.adminEmail, role: "admin" }, config.jwtSecret, { expiresIn: "12h" });
  return res.json({ token, email: config.adminEmail });
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice("Bearer ".length) : "";
  if (!token) return res.status(401).json({ error: "Missing bearer token." });

  try {
    jwt.verify(token, config.jwtSecret);
    return next();
  } catch {
    return res.status(401).json({ error: "Invalid or expired token." });
  }
}
