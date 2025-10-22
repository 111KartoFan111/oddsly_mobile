const express = require("express");
const admin = require("firebase-admin");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const cors = require("cors");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

// --- Инициализация ---
const serviceAccount = require("./serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();
const app = express();
const PORT = process.env.PORT || 3000;

// --- Middleware ---
app.use(cors({
  origin: '*',
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));

const verifyToken = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (token == null) return res.sendStatus(401);

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
};

// --- Helper: Read matches from JSON ---
const loadMatches = () => {
  try {
    const data = fs.readFileSync(path.join(__dirname, "matches.json"), "utf8");
    return JSON.parse(data);
  } catch (error) {
    console.error("Error loading matches.json:", error.message);
    return { football: [], basketball: [], tennis: [] };
  }
};

const getUpcomingMatches = (sport, daysAhead = 7) => {
  const allMatches = loadMatches();
  const sportMatches = allMatches[sport] || [];

  const now = new Date();

  return sportMatches
    .filter((match) => {
      const matchDate = new Date(match.matchDate);
      // Показываем все матчи которые еще не прошли (в будущем или сегодня)
      return (
        matchDate >= new Date(now.getFullYear(), now.getMonth(), now.getDate())
      );
    })
    .map((match) => ({
      ...match,
      sport: sport,
      team1Score: match.status === "live" ? match.team1Score || 0 : 0,
      team2Score: match.status === "live" ? match.team2Score || 0 : 0,
      time: match.status === "live" ? match.time || "Live" : "00:00",
    }))
    .sort((a, b) => new Date(a.matchDate) - new Date(b.matchDate))
    .slice(0, 20);
};

// --- AUTH ---
app.post("/register", async (req, res) => {
  try {
    const { email, password, name, surname } = req.body;
    if (!email || !password) {
      return res
        .status(400)
        .send({ message: "Email and password are required." });
    }

    const existingUser = await db
      .collection("users")
      .where("email", "==", email)
      .limit(1)
      .get();
    if (!existingUser.empty) {
      return res.status(409).send({ message: "User already exists." });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const userRef = db.collection("users").doc();
    await userRef.set({
      email: email,
      password: hashedPassword,
      name: name || "",
      surname: surname || "",
      balance: 10000,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const token = jwt.sign(
      { id: userRef.id, email: email },
      process.env.JWT_SECRET,
      { expiresIn: "24h" }
    );
    res.status(201).send({ message: "User created successfully.", token });
  } catch (error) {
    res
      .status(500)
      .send({ message: "Error creating user.", error: error.message });
  }
});

app.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res
        .status(400)
        .send({ message: "Email and password are required." });
    }
    const usersRef = db.collection("users");
    const snapshot = await usersRef.where("email", "==", email).limit(1).get();
    if (snapshot.empty) {
      return res.status(404).send({ message: "User not found." });
    }
    const userDoc = snapshot.docs[0];
    const user = userDoc.data();
    const isPasswordCorrect = await bcrypt.compare(password, user.password);
    if (!isPasswordCorrect) {
      return res.status(401).send({ message: "Invalid credentials." });
    }
    const token = jwt.sign(
      { id: userDoc.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: "24h" }
    );
    res.status(200).send({ message: "Login successful.", token: token });
  } catch (error) {
    res
      .status(500)
      .send({ message: "Error logging in.", error: error.message });
  }
});

app.get("/me", verifyToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const userRef = db.collection("users").doc(userId);
    const doc = await userRef.get();
    if (!doc.exists) {
      return res.status(404).send({ message: "User not found." });
    }
    const { password, ...userData } = doc.data();
    res.status(200).send(userData);
  } catch (error) {
    res
      .status(500)
      .send({ message: "Error fetching user data.", error: error.message });
  }
});


app.get("/matches", async (req, res) => {
  try {
    const { status, league, limit = 20 } = req.query;

    let query = db.collection("matches");

    if (status) {
      query = query.where("status", "==", status);
    }
    if (league) {
      query = query.where("league", "==", league);
    }

    query = query.limit(parseInt(limit));

    const snapshot = await query.get();

    if (snapshot.empty) {
      return res.status(200).send([]);
    }

    const matches = await Promise.all(
      snapshot.docs.map(async (doc) => {
        const matchData = { id: doc.id, ...doc.data() };

        const bettingOptionsSnapshot = await doc.ref
          .collection("bettingOptions")
          .get();

        matchData.bettingOptions = bettingOptionsSnapshot.docs.map(
          (betDoc) => ({
            id: betDoc.id,
            ...betDoc.data(),
          })
        );

        return matchData;
      })
    );

    res.status(200).send(matches);
  } catch (error) {
    console.error("Error fetching matches:", error);
    res
      .status(500)
      .send({ message: "Error fetching matches.", error: error.message });
  }
});

// --- MATCHES ---
app.get("/matches/live", (req, res) => {
  const { sport = "football" } = req.query;
  console.log(`📡 Fetching ${sport} matches (next 3 days)...`);

  try {
    const matches = getUpcomingMatches(sport, 3);
    console.log(`✓ Returning ${matches.length} ${sport} matches`);
    res.status(200).send(matches);
  } catch (error) {
    console.error("Error in /matches/live:", error);
    res
      .status(500)
      .send({ message: "Error fetching matches.", error: error.message });
  }
});

app.get("/matches/:matchId", async (req, res) => {
  const { matchId } = req.params;

  try {
    // Проверяем Firestore (созданные админом)
    const matchDoc = await db.collection("matches").doc(matchId).get();
    if (matchDoc.exists) {
      const matchData = matchDoc.data();
      const bettingOptions = await matchDoc.ref
        .collection("bettingOptions")
        .get();
      const odds = {};
      bettingOptions.forEach((doc) => {
        const data = doc.data();
        odds[data.type] = data.coefficient;
      });
      return res.status(200).send({ id: matchDoc.id, ...matchData, odds });
    }

    // Ищем в JSON файле
    const allMatches = loadMatches();
    const allSports = ["football", "basketball", "tennis"];

    for (const sport of allSports) {
      const match = allMatches[sport]?.find((m) => m.id === matchId);
      if (match) {
        return res.status(200).send({
          ...match,
          sport: sport,
          team1Score: match.team1Score || 0,
          team2Score: match.team2Score || 0,
          time: match.time || "00:00",
        });
      }
    }

    res.status(404).send({ message: "Match not found." });
  } catch (error) {
    res
      .status(500)
      .send({ message: "Error fetching match.", error: error.message });
  }
});

// --- BETS ---
app.post("/bet", verifyToken, async (req, res) => {
  const { matchId, amount, outcome, matchInfo } = req.body;
  const userId = req.user.id;

  if (!matchId || !amount || !outcome) {
    return res
      .status(400)
      .send({ message: "Match ID, amount, and outcome are required." });
  }

  const userRef = db.collection("users").doc(userId);
  const betRef = db.collection("bets").doc();

  try {
    const newBalance = await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        throw new Error("User not found.");
      }

      const currentBalance = userDoc.data().balance;
      if (currentBalance < amount) {
        throw new Error("Insufficient funds.");
      }

      const updatedBalance = currentBalance - amount;

      transaction.set(betRef, {
        userId,
        matchId,
        amount,
        outcome,
        status: "active",
        // Сохраняем информацию о матче
        team1Name: matchInfo?.team1Name || "Unknown",
        team2Name: matchInfo?.team2Name || "Unknown",
        league: matchInfo?.league || "Unknown",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(userRef, { balance: updatedBalance });

      return updatedBalance;
    });

    res.status(201).send({
      message: "Bet placed successfully.",
      betId: betRef.id,
      newBalance: newBalance,
    });
  } catch (error) {
    if (error.message === "Insufficient funds.") {
      return res.status(402).send({ message: "Недостаточно средств." });
    }
    res
      .status(500)
      .send({ message: "Error placing bet.", error: error.message });
  }
});

app.get("/my-bets", verifyToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const betsRef = db.collection("bets");

    const snapshot = await betsRef
      .where("userId", "==", userId)
      .limit(100)
      .get();

    if (snapshot.empty) {
      return res.status(200).send([]);
    }

    const bets = snapshot.docs
      .map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          userId: data.userId,
          matchId: data.matchId,
          amount: data.amount,
          outcome: data.outcome,
          status: data.status,
          team1Name: data.team1Name || "Unknown",
          team2Name: data.team2Name || "Unknown",
          league: data.league || "Unknown",
          createdAt: data.createdAt
            ? data.createdAt.toDate
              ? data.createdAt.toDate().toISOString()
              : data.createdAt
            : new Date().toISOString(),
        };
      })
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.status(200).send(bets);
  } catch (error) {
    console.error("Error in /my-bets:", error);
    res
      .status(500)
      .send({ message: "Error getting bet history.", error: error.message });
  }
});

// --- ADMIN ---
app.get("/admin", async (req, res) => {
  try {
    const matchesSnapshot = await db
      .collection("matches")
      .orderBy("matchDate", "desc")
      .get();
    const matches = matchesSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    res.render("admin", { title: "Admin Panel", matches: matches });
  } catch (error) {
    res
      .status(500)
      .send({ message: "Error fetching matches.", error: error.message });
  }
});

app.post("/admin/matches", async (req, res) => {
  try {
    const { team1Name, team2Name, league, matchDate } = req.body;
    const matchId = `${team1Name.replace(/\s+/g, "")}_vs_${team2Name.replace(
      /\s+/g,
      ""
    )}_${Date.now()}`;

    const matchRef = db.collection("matches").doc(matchId);

    await matchRef.set({
      team1Name,
      team2Name,
      league,
      matchDate: new Date(matchDate),
      team1Score: 0,
      team2Score: 0,
      time: "00:00",
      status: "scheduled",
      sport: "football",
    });

    const defaultBetTypes = [
      { type: "П1", coefficient: 2.1 },
      { type: "X", coefficient: 3.4 },
      { type: "П2", coefficient: 2.95 },
    ];
    const betsRef = matchRef.collection("bettingOptions");
    for (const bet of defaultBetTypes) {
      await betsRef.add(bet);
    }
    res.redirect("/admin");
  } catch (error) {
    res
      .status(500)
      .send({ message: "Error creating match.", error: error.message });
  }
});

app.post("/deposit", verifyToken, async (req, res) => {
  const { amount, method, cardNumber } = req.body;
  const userId = req.user.id;

  if (!amount || amount < 200) {
    return res.status(400).send({ message: "Минимальная сумма 200₸" });
  }

  const userRef = db.collection("users").doc(userId);
  const transactionRef = db.collection("transactions").doc();

  try {
    const newBalance = await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        throw new Error("User not found.");
      }

      const currentBalance = userDoc.data().balance;
      const commission = method === "card" ? amount * 0.05 : 0;
      const depositAmount = amount - commission;
      const updatedBalance = currentBalance + depositAmount;

      transaction.update(userRef, { balance: updatedBalance });

      transaction.set(transactionRef, {
        userId,
        type: "deposit",
        amount: amount, // Исходная сумма
        commission: commission, // Комиссия
        netAmount: depositAmount, // Чистая сумма на баланс
        status: "completed",
        cardNumber: cardNumber || "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return updatedBalance;
    });

    res.status(200).send({
      message: "Баланс пополнен успешно",
      newBalance: newBalance,
    });
  } catch (error) {
    res
      .status(500)
      .send({ message: "Ошибка пополнения", error: error.message });
  }
});

app.post("/withdraw", verifyToken, async (req, res) => {
  const { amount, cardNumber } = req.body;
  const userId = req.user.id;

  if (!amount || amount < 200) {
    return res.status(400).send({ message: "Минимальная сумма вывода 200₸" });
  }

  if (!cardNumber) {
    return res.status(400).send({ message: "Укажите номер карты" });
  }

  const userRef = db.collection("users").doc(userId);
  const transactionRef = db.collection("transactions").doc();

  try {
    const newBalance = await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        throw new Error("User not found.");
      }

      const currentBalance = userDoc.data().balance;
      const commission = amount * 0.05;
      const totalAmount = amount + commission;

      if (currentBalance < totalAmount) {
        throw new Error("Недостаточно средств на балансе");
      }

      const updatedBalance = currentBalance - totalAmount;

      transaction.update(userRef, { balance: updatedBalance });

      transaction.set(transactionRef, {
        userId,
        type: "withdrawal",
        amount: amount, // Исходная сумма вывода
        commission: commission, // Комиссия
        totalAmount: totalAmount, // Общая списанная сумма
        status: "completed",
        cardNumber: cardNumber,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return updatedBalance;
    });

    res.status(200).send({
      message: "Вывод выполнен успешно",
      newBalance: newBalance,
    });
  } catch (error) {
    if (error.message === "Недостаточно средств на балансе") {
      return res.status(400).send({ message: error.message });
    }
    res.status(500).send({ message: "Ошибка вывода", error: error.message });
  }
});

app.get("/transactions", verifyToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const transactionsRef = db.collection("transactions");

    const snapshot = await transactionsRef
      .where("userId", "==", userId)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();

    if (snapshot.empty) {
      return res.status(200).send([]);
    }

    const transactions = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        type: data.type,
        amount: data.amount,
        status: data.status || "completed",
        cardNumber: data.cardNumber || "",
        createdAt: data.createdAt
          ? data.createdAt.toDate
            ? data.createdAt.toDate().toISOString()
            : data.createdAt
          : new Date().toISOString(),
      };
    });

    res.status(200).send(transactions);
  } catch (error) {
    console.error("Error in /transactions:", error);
    res.status(500).send({
      message: "Error getting transaction history.",
      error: error.message,
    });
  }
});

app.post("/admin/matches/update", async (req, res) => {
  const { matchId, team1Score, team2Score } = req.body;

  if (!matchId || team1Score == null || team2Score == null) {
    return res.status(400).send({ message: "Missing required fields." });
  }

  const matchRef = db.collection("matches").doc(matchId);

  try {
    await matchRef.update({
      team1Score: parseInt(team1Score, 10),
      team2Score: parseInt(team2Score, 10),
      status: "finished",
    });

    let winningOutcome;
    const t1Score = parseInt(team1Score, 10);
    const t2Score = parseInt(team2Score, 10);

    if (t1Score > t2Score) {
      winningOutcome = "П1";
    } else if (t1Score < t2Score) {
      winningOutcome = "П2";
    } else {
      winningOutcome = "X";
    }

    const betsSnapshot = await db
      .collection("bets")
      .where("matchId", "==", matchId)
      .where("status", "==", "active")
      .get();

    if (betsSnapshot.empty) {
      return res.redirect("/admin");
    }

    const batch = db.batch();
    for (const doc of betsSnapshot.docs) {
      const bet = doc.data();
      const betRef = doc.ref;
      const userRef = db.collection("users").doc(bet.userId);

      const betParts = bet.outcome.split(" - ");
      const betType = betParts[0];
      const coefficient = parseFloat(betParts[1]);

      if (betType === winningOutcome) {
        const winnings = bet.amount * coefficient;
        batch.update(betRef, { status: "won" });
        batch.update(userRef, {
          balance: admin.firestore.FieldValue.increment(winnings),
        });
      } else {
        batch.update(betRef, { status: "lost" });
      }
    }

    await batch.commit();
    res.redirect("/admin");
  } catch (error) {
    console.error("Error settling bets:", error);
    res
      .status(500)
      .send({ message: "Error settling bets.", error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
