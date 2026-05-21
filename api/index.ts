type MatchStatus = "lobby" | "in_progress" | "finished" | "abandoned";
type SceneKey = "campaign_1" | "vs_map_1";
type ResetReason = "barrier" | "tee";

interface Vector2 {
  x: number;
  y: number;
}

interface BallState {
  playerId: string;
  position: Vector2;
  linearVelocity: Vector2;
  angularVelocity: number;
  isHoled: boolean;
  strokeCount: number;
}

interface PlayerInfo {
  playerId: string;
  name: string;
  connected: boolean;
  isHost: boolean;
  colorIndex: number;
}

interface MatchSnapshot {
  matchId: string;
  joinCode: string;
  sceneKey: SceneKey;
  status: MatchStatus;
  turnNumber: number;
  activePlayerId: string | null;
  players: PlayerInfo[];
  balls: BallState[];
  winnerPlayerId: string | null;
  updatedAt: string;
}

interface ErrorResponse {
  error: { code: string; message: string };
}

interface GuestAuthRequest {
  name: string;
}
interface GuestAuthResponse {
  playerId: string;
  token: string;
  expiresAt: string;
}

interface CreateMatchRequest {
  sceneKey: SceneKey;
  maxPlayers: 2 | 3 | 4;
}
interface CreateMatchResponse {
  match: MatchSnapshot;
}

interface JoinMatchRequest {
  joinCode: string;
}
interface JoinMatchResponse {
  match: MatchSnapshot;
}

interface StartMatchRequest {}
interface StartMatchResponse {
  match: MatchSnapshot;
}

interface SubmitShotRequest {
  playerId: string;
  turnNumber: number;
  direction: Vector2;
  power01: number;
  clientShotId: string;
  clientTimeMs: number;
}
interface SubmitShotResponse {
  accepted: boolean;
  reason?: "not_your_turn" | "turn_mismatch" | "invalid_power" | "match_not_live";
  authoritativeImpulse?: Vector2;
  match?: MatchSnapshot;
}

interface BallHoledEventRequest {
  playerId: string;
  turnNumber: number;
  at: Vector2;
}

interface BallResetEventRequest {
  playerId: string;
  turnNumber: number;
  reason: ResetReason;
  resetTo: Vector2;
}

interface LeaveMatchRequest {
  playerId: string;
}
interface HeartbeatRequest {
  playerId: string;
  lastAckEventId?: string;
}

type ServerEvent =
  | { type: "lobby_updated"; match: MatchSnapshot }
  | { type: "match_started"; match: MatchSnapshot }
  | { type: "turn_started"; matchId: string; turnNumber: number; activePlayerId: string; deadlineMs?: number }
  | { type: "shot_applied"; matchId: string; playerId: string; turnNumber: number; impulse: Vector2; match: MatchSnapshot }
  | { type: "state_snapshot"; match: MatchSnapshot }
  | { type: "player_disconnected"; matchId: string; playerId: string }
  | { type: "match_finished"; match: MatchSnapshot }
  | { type: "error"; code: string; message: string };

type ClientEvent =
  | { type: "ping"; t: number }
  | { type: "ack"; eventType: ServerEvent["type"]; turnNumber?: number }
  | { type: "client_ready"; matchId: string; playerId: string };

interface PlayerSession {
  playerId: string;
  name: string;
  token: string;
  expiresAt: string;
}

interface MatchRecord {
  matchId: string;
  joinCode: string;
  sceneKey: SceneKey;
  status: MatchStatus;
  maxPlayers: 2 | 3 | 4;
  turnNumber: number;
  activePlayerId: string | null;
  players: PlayerInfo[];
  balls: BallState[];
  winnerPlayerId: string | null;
  updatedAt: string;
}

interface WsData {
  matchId: string;
  playerId: string;
}

const playerSessions = new Map<string, PlayerSession>();
const matches = new Map<string, MatchRecord>();
const socketsByMatch = new Map<string, Set<Bun.ServerWebSocket<WsData>>>();

const sceneKeys = new Set<SceneKey>(["campaign_1", "vs_map_1"]);
const powerScale = 1000;
const sessionTtlMs = 1000 * 60 * 60 * 24;
const port = Number(Bun.env.PORT ?? "8787");

const json = (data: unknown, status = 200): Response =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json" },
  });

const err = (code: string, message: string, status: number): Response =>
  json({ error: { code, message } satisfies ErrorResponse["error"] }, status);

const nowIso = () => new Date().toISOString();

const randomId = (prefix: string) => `${prefix}_${crypto.randomUUID().replace(/-/g, "")}`;

const randomJoinCode = () => Math.random().toString(36).slice(2, 8).toUpperCase();

const cloneSnapshot = (match: MatchRecord): MatchSnapshot => ({
  matchId: match.matchId,
  joinCode: match.joinCode,
  sceneKey: match.sceneKey,
  status: match.status,
  turnNumber: match.turnNumber,
  activePlayerId: match.activePlayerId,
  players: match.players.map((p) => ({ ...p })),
  balls: match.balls.map((b) => ({
    ...b,
    position: { ...b.position },
    linearVelocity: { ...b.linearVelocity },
  })),
  winnerPlayerId: match.winnerPlayerId,
  updatedAt: match.updatedAt,
});

const touchMatch = (match: MatchRecord) => {
  match.updatedAt = nowIso();
};

const parseBody = async <T>(req: Request): Promise<T | null> => {
  try {
    if (!req.headers.get("content-type")?.includes("application/json")) {
      return null;
    }
    return (await req.json()) as T;
  } catch {
    return null;
  }
};

const isFiniteNumber = (value: unknown): value is number => typeof value === "number" && Number.isFinite(value);

const isVector2 = (value: unknown): value is Vector2 =>
  typeof value === "object" &&
  value !== null &&
  isFiniteNumber((value as Vector2).x) &&
  isFiniteNumber((value as Vector2).y);

const getSessionFromHeaders = (req: Request): PlayerSession | null => {
  const playerId = req.headers.get("x-player-id");
  const token = req.headers.get("x-token");
  if (!playerId || !token) return null;
  const session = playerSessions.get(playerId);
  if (!session || session.token !== token) return null;
  if (new Date(session.expiresAt).getTime() < Date.now()) {
    playerSessions.delete(playerId);
    return null;
  }
  return session;
};

const getMatch = (matchId: string): MatchRecord | null => matches.get(matchId) ?? null;
const getPathMatchId = (matchResult: RegExpMatchArray | null): string | null => {
  const id = matchResult?.[1];
  return id ? decodeURIComponent(id) : null;
};

const getPlayerIndex = (match: MatchRecord, playerId: string): number => match.players.findIndex((p) => p.playerId === playerId);

const getBall = (match: MatchRecord, playerId: string): BallState | null =>
  match.balls.find((b) => b.playerId === playerId) ?? null;

const nextTurnPlayerId = (match: MatchRecord, previousPlayerId: string | null): string | null => {
  if (match.players.length === 0) return null;
  const eligible = match.players.filter((p) => match.balls.find((b) => b.playerId === p.playerId && !b.isHoled));
  if (eligible.length === 0) return null;
  const currentIdx = previousPlayerId ? eligible.findIndex((p) => p.playerId === previousPlayerId) : -1;
  const nextIdx = currentIdx === -1 ? 0 : (currentIdx + 1) % eligible.length;
  return eligible[nextIdx]?.playerId ?? null;
};

const wsSend = (ws: Bun.ServerWebSocket<WsData>, event: ServerEvent) => {
  ws.send(JSON.stringify(event));
};

const broadcastToMatch = (matchId: string, event: ServerEvent) => {
  const sockets = socketsByMatch.get(matchId);
  if (!sockets || sockets.size === 0) return;
  const serialized = JSON.stringify(event);
  for (const ws of sockets) ws.send(serialized);
};

const broadcastSnapshot = (match: MatchRecord, eventType: "lobby_updated" | "match_started" | "match_finished" = "lobby_updated") => {
  const snapshot = cloneSnapshot(match);
  if (eventType === "lobby_updated") {
    broadcastToMatch(match.matchId, { type: "lobby_updated", match: snapshot });
    return;
  }
  if (eventType === "match_started") {
    broadcastToMatch(match.matchId, { type: "match_started", match: snapshot });
    return;
  }
  broadcastToMatch(match.matchId, { type: "match_finished", match: snapshot });
};

const finishIfSinglePlayerLeft = (match: MatchRecord): boolean => {
  if (match.status !== "in_progress") return false;
  if (match.players.length > 1) return false;
  match.status = "finished";
  match.winnerPlayerId = match.players[0]?.playerId ?? null;
  match.activePlayerId = null;
  touchMatch(match);
  broadcastSnapshot(match, "match_finished");
  return true;
};

const applyDisconnect = (match: MatchRecord, playerId: string) => {
  const idx = getPlayerIndex(match, playerId);
  if (idx === -1) return;
  const player = match.players[idx];
  if (!player) return;
  match.players[idx] = { ...player, connected: false };
  if (match.activePlayerId === playerId && match.status === "in_progress") {
    match.activePlayerId = nextTurnPlayerId(match, playerId);
    match.turnNumber += 1;
    if (match.activePlayerId) {
      broadcastToMatch(match.matchId, {
        type: "turn_started",
        matchId: match.matchId,
        turnNumber: match.turnNumber,
        activePlayerId: match.activePlayerId,
      });
    }
  }
  touchMatch(match);
  broadcastToMatch(match.matchId, { type: "player_disconnected", matchId: match.matchId, playerId });
  broadcastSnapshot(match, "lobby_updated");
};

const server = Bun.serve<WsData>({
  port,
  fetch: async (req, serverRef) => {
    const url = new URL(req.url);
    const path = url.pathname;
    const method = req.method.toUpperCase();

    if (method === "GET" && path === "/health") {
      return json({ ok: true, ts: nowIso() });
    }

    if (method === "POST" && path === "/v1/auth/guest") {
      const body = await parseBody<GuestAuthRequest>(req);
      if (!body || typeof body.name !== "string" || body.name.trim().length < 1 || body.name.trim().length > 20) {
        return err("invalid_request", "name must be 1-20 chars", 400);
      }
      const playerId = randomId("p");
      const token = randomId("tok");
      const expiresAt = new Date(Date.now() + sessionTtlMs).toISOString();
      playerSessions.set(playerId, { playerId, name: body.name.trim(), token, expiresAt });
      const response: GuestAuthResponse = { playerId, token, expiresAt };
      return json(response, 201);
    }

    if (method === "POST" && path === "/v1/matches") {
      const session = getSessionFromHeaders(req);
      if (!session) return err("unauthorized", "missing or invalid session headers", 401);
      const body = await parseBody<CreateMatchRequest>(req);
      if (!body || !sceneKeys.has(body.sceneKey) || ![2, 3, 4].includes(body.maxPlayers)) {
        return err("invalid_request", "sceneKey or maxPlayers invalid", 400);
      }
      const matchId = randomId("m");
      const joinCode = randomJoinCode();
      const createdAt = nowIso();
      const hostPlayer: PlayerInfo = {
        playerId: session.playerId,
        name: session.name,
        connected: true,
        isHost: true,
        colorIndex: 0,
      };
      const match: MatchRecord = {
        matchId,
        joinCode,
        sceneKey: body.sceneKey,
        status: "lobby",
        maxPlayers: body.maxPlayers,
        turnNumber: 0,
        activePlayerId: null,
        players: [hostPlayer],
        balls: [
          {
            playerId: session.playerId,
            position: { x: 0, y: 0 },
            linearVelocity: { x: 0, y: 0 },
            angularVelocity: 0,
            isHoled: false,
            strokeCount: 0,
          },
        ],
        winnerPlayerId: null,
        updatedAt: createdAt,
      };
      matches.set(matchId, match);
      const response: CreateMatchResponse = { match: cloneSnapshot(match) };
      return json(response, 201);
    }

    const matchIdOnly = path.match(/^\/v1\/matches\/([^/]+)$/);
    if (method === "GET" && matchIdOnly) {
      const matchId = getPathMatchId(matchIdOnly);
      if (!matchId) return err("invalid_request", "matchId missing", 400);
      const match = getMatch(matchId);
      if (!match) return err("not_found", "match not found", 404);
      return json({ match: cloneSnapshot(match) });
    }

    const joinPath = path.match(/^\/v1\/matches\/([^/]+)\/join$/);
    if (method === "POST" && joinPath) {
      const session = getSessionFromHeaders(req);
      if (!session) return err("unauthorized", "missing or invalid session headers", 401);
      const matchId = getPathMatchId(joinPath);
      if (!matchId) return err("invalid_request", "matchId missing", 400);
      const match = getMatch(matchId);
      if (!match) return err("not_found", "match not found", 404);
      const body = await parseBody<JoinMatchRequest>(req);
      if (!body || typeof body.joinCode !== "string" || body.joinCode.trim().toUpperCase() !== match.joinCode) {
        return err("invalid_join_code", "joinCode does not match", 400);
      }
      if (match.status !== "lobby") return err("match_not_joinable", "match already started", 409);
      const existingIdx = getPlayerIndex(match, session.playerId);
      if (existingIdx >= 0) {
        const existingPlayer = match.players[existingIdx];
        if (!existingPlayer) return err("internal_error", "player slot missing", 500);
        match.players[existingIdx] = { ...existingPlayer, connected: true, name: session.name };
      } else {
        if (match.players.length >= match.maxPlayers) return err("match_full", "match has no free slots", 409);
        match.players.push({
          playerId: session.playerId,
          name: session.name,
          connected: true,
          isHost: false,
          colorIndex: match.players.length,
        });
        match.balls.push({
          playerId: session.playerId,
          position: { x: 0, y: 0 },
          linearVelocity: { x: 0, y: 0 },
          angularVelocity: 0,
          isHoled: false,
          strokeCount: 0,
        });
      }
      touchMatch(match);
      broadcastSnapshot(match, "lobby_updated");
      const response: JoinMatchResponse = { match: cloneSnapshot(match) };
      return json(response);
    }

    const startPath = path.match(/^\/v1\/matches\/([^/]+)\/start$/);
    if (method === "POST" && startPath) {
      const session = getSessionFromHeaders(req);
      if (!session) return err("unauthorized", "missing or invalid session headers", 401);
      const matchId = getPathMatchId(startPath);
      if (!matchId) return err("invalid_request", "matchId missing", 400);
      const match = getMatch(matchId);
      if (!match) return err("not_found", "match not found", 404);
      const host = match.players.find((p) => p.isHost);
      if (!host || host.playerId !== session.playerId) return err("forbidden", "only host can start", 403);
      if (match.status !== "lobby") return err("invalid_state", "match not in lobby", 409);
      if (match.players.length < 2) return err("not_enough_players", "need at least 2 players", 409);
      match.status = "in_progress";
      match.turnNumber = 1;
      match.activePlayerId = nextTurnPlayerId(match, null);
      touchMatch(match);
      broadcastSnapshot(match, "match_started");
      if (match.activePlayerId) {
        broadcastToMatch(match.matchId, {
          type: "turn_started",
          matchId: match.matchId,
          turnNumber: match.turnNumber,
          activePlayerId: match.activePlayerId,
        });
      }
      const response: StartMatchResponse = { match: cloneSnapshot(match) };
      return json(response);
    }

    const shotsPath = path.match(/^\/v1\/matches\/([^/]+)\/shots$/);
    if (method === "POST" && shotsPath) {
      const session = getSessionFromHeaders(req);
      if (!session) return err("unauthorized", "missing or invalid session headers", 401);
      const matchId = getPathMatchId(shotsPath);
      if (!matchId) return err("invalid_request", "matchId missing", 400);
      const match = getMatch(matchId);
      if (!match) return err("not_found", "match not found", 404);
      const body = await parseBody<SubmitShotRequest>(req);
      if (
        !body ||
        typeof body.playerId !== "string" ||
        !Number.isInteger(body.turnNumber) ||
        !isVector2(body.direction) ||
        !isFiniteNumber(body.power01) ||
        typeof body.clientShotId !== "string" ||
        !isFiniteNumber(body.clientTimeMs)
      ) {
        return err("invalid_request", "invalid shot payload", 400);
      }
      if (body.playerId !== session.playerId) return err("forbidden", "player ownership mismatch", 403);
      if (match.status !== "in_progress") {
        const response: SubmitShotResponse = { accepted: false, reason: "match_not_live", match: cloneSnapshot(match) };
        return json(response, 409);
      }
      if (body.playerId !== match.activePlayerId) {
        const response: SubmitShotResponse = { accepted: false, reason: "not_your_turn", match: cloneSnapshot(match) };
        return json(response, 409);
      }
      if (body.turnNumber !== match.turnNumber) {
        const response: SubmitShotResponse = { accepted: false, reason: "turn_mismatch", match: cloneSnapshot(match) };
        return json(response, 409);
      }
      if (body.power01 < 0 || body.power01 > 1) {
        const response: SubmitShotResponse = { accepted: false, reason: "invalid_power", match: cloneSnapshot(match) };
        return json(response, 400);
      }
      const length = Math.hypot(body.direction.x, body.direction.y);
      if (length <= 0) {
        const response: SubmitShotResponse = { accepted: false, reason: "invalid_power", match: cloneSnapshot(match) };
        return json(response, 400);
      }
      const direction = { x: body.direction.x / length, y: body.direction.y / length };
      const impulse = { x: direction.x * body.power01 * powerScale, y: direction.y * body.power01 * powerScale };
      const ball = getBall(match, body.playerId);
      if (!ball) return err("forbidden", "player has no ball in this match", 403);
      ball.linearVelocity = impulse;
      ball.strokeCount += 1;
      match.turnNumber += 1;
      match.activePlayerId = nextTurnPlayerId(match, body.playerId);
      touchMatch(match);
      const snapshot = cloneSnapshot(match);
      broadcastToMatch(match.matchId, {
        type: "shot_applied",
        matchId: match.matchId,
        playerId: body.playerId,
        turnNumber: body.turnNumber,
        impulse,
        match: snapshot,
      });
      if (match.activePlayerId) {
        broadcastToMatch(match.matchId, {
          type: "turn_started",
          matchId: match.matchId,
          turnNumber: match.turnNumber,
          activePlayerId: match.activePlayerId,
        });
      }
      const response: SubmitShotResponse = {
        accepted: true,
        authoritativeImpulse: impulse,
        match: snapshot,
      };
      return json(response);
    }

    const holedPath = path.match(/^\/v1\/matches\/([^/]+)\/events\/ball-holed$/);
    if (method === "POST" && holedPath) {
      const session = getSessionFromHeaders(req);
      if (!session) return err("unauthorized", "missing or invalid session headers", 401);
      const matchId = getPathMatchId(holedPath);
      if (!matchId) return err("invalid_request", "matchId missing", 400);
      const match = getMatch(matchId);
      if (!match) return err("not_found", "match not found", 404);
      const body = await parseBody<BallHoledEventRequest>(req);
      if (!body || typeof body.playerId !== "string" || !Number.isInteger(body.turnNumber) || !isVector2(body.at)) {
        return err("invalid_request", "invalid ball-holed payload", 400);
      }
      if (body.playerId !== session.playerId) return err("forbidden", "player ownership mismatch", 403);
      if (body.turnNumber !== match.turnNumber && body.turnNumber !== match.turnNumber - 1) {
        return err("turn_mismatch", "turn number mismatch", 409);
      }
      const ball = getBall(match, body.playerId);
      if (!ball) return err("forbidden", "player has no ball in this match", 403);
      ball.isHoled = true;
      ball.position = { ...body.at };
      ball.linearVelocity = { x: 0, y: 0 };
      ball.angularVelocity = 0;
      const remaining = match.balls.filter((b) => !b.isHoled);
      if (remaining.length === 0) {
        match.status = "finished";
        const winnerBall = [...match.balls].sort((a, b) => a.strokeCount - b.strokeCount)[0];
        match.winnerPlayerId = winnerBall?.playerId ?? body.playerId;
        match.activePlayerId = null;
      } else if (match.activePlayerId === body.playerId) {
        match.activePlayerId = nextTurnPlayerId(match, body.playerId);
      }
      touchMatch(match);
      const snapshot = cloneSnapshot(match);
      broadcastToMatch(match.matchId, { type: "state_snapshot", match: snapshot });
      if (match.status === "finished") {
        broadcastToMatch(match.matchId, { type: "match_finished", match: snapshot });
      }
      return json({ match: snapshot });
    }

    const resetPath = path.match(/^\/v1\/matches\/([^/]+)\/events\/ball-reset$/);
    if (method === "POST" && resetPath) {
      const session = getSessionFromHeaders(req);
      if (!session) return err("unauthorized", "missing or invalid session headers", 401);
      const matchId = getPathMatchId(resetPath);
      if (!matchId) return err("invalid_request", "matchId missing", 400);
      const match = getMatch(matchId);
      if (!match) return err("not_found", "match not found", 404);
      const body = await parseBody<BallResetEventRequest>(req);
      if (
        !body ||
        typeof body.playerId !== "string" ||
        !Number.isInteger(body.turnNumber) ||
        !["barrier", "tee"].includes(body.reason) ||
        !isVector2(body.resetTo)
      ) {
        return err("invalid_request", "invalid ball-reset payload", 400);
      }
      if (body.playerId !== session.playerId) return err("forbidden", "player ownership mismatch", 403);
      if (body.turnNumber !== match.turnNumber && body.turnNumber !== match.turnNumber - 1) {
        return err("turn_mismatch", "turn number mismatch", 409);
      }
      const ball = getBall(match, body.playerId);
      if (!ball) return err("forbidden", "player has no ball in this match", 403);
      ball.position = { ...body.resetTo };
      ball.linearVelocity = { x: 0, y: 0 };
      ball.angularVelocity = 0;
      touchMatch(match);
      const snapshot = cloneSnapshot(match);
      broadcastToMatch(match.matchId, { type: "state_snapshot", match: snapshot });
      return json({ match: snapshot });
    }

    const leavePath = path.match(/^\/v1\/matches\/([^/]+)\/leave$/);
    if (method === "POST" && leavePath) {
      const session = getSessionFromHeaders(req);
      if (!session) return err("unauthorized", "missing or invalid session headers", 401);
      const matchId = getPathMatchId(leavePath);
      if (!matchId) return err("invalid_request", "matchId missing", 400);
      const match = getMatch(matchId);
      if (!match) return err("not_found", "match not found", 404);
      const body = await parseBody<LeaveMatchRequest>(req);
      if (!body || typeof body.playerId !== "string") return err("invalid_request", "invalid leave payload", 400);
      if (body.playerId !== session.playerId) return err("forbidden", "player ownership mismatch", 403);
      const idx = getPlayerIndex(match, body.playerId);
      if (idx === -1) return err("not_found", "player not in match", 404);
      const leavingPlayer = match.players[idx];
      if (!leavingPlayer) return err("internal_error", "player slot missing", 500);
      match.players.splice(idx, 1);
      match.balls = match.balls.filter((b) => b.playerId !== body.playerId);
      if (leavingPlayer.isHost && match.players.length > 0) {
        const nextHost = match.players[0];
        if (nextHost) match.players[0] = { ...nextHost, isHost: true };
      }
      if (match.activePlayerId === body.playerId) {
        match.activePlayerId = nextTurnPlayerId(match, body.playerId);
        match.turnNumber += 1;
      }
      if (match.players.length === 0) {
        match.status = "abandoned";
        match.activePlayerId = null;
      } else {
        finishIfSinglePlayerLeft(match);
      }
      touchMatch(match);
      if (match.status === "finished" || match.status === "abandoned") {
        broadcastSnapshot(match, "match_finished");
      } else {
        broadcastSnapshot(match, "lobby_updated");
      }
      return json({ match: cloneSnapshot(match) });
    }

    const heartbeatPath = path.match(/^\/v1\/matches\/([^/]+)\/heartbeat$/);
    if (method === "POST" && heartbeatPath) {
      const session = getSessionFromHeaders(req);
      if (!session) return err("unauthorized", "missing or invalid session headers", 401);
      const matchId = getPathMatchId(heartbeatPath);
      if (!matchId) return err("invalid_request", "matchId missing", 400);
      const match = getMatch(matchId);
      if (!match) return err("not_found", "match not found", 404);
      const body = await parseBody<HeartbeatRequest>(req);
      if (!body || typeof body.playerId !== "string") return err("invalid_request", "invalid heartbeat payload", 400);
      if (body.playerId !== session.playerId) return err("forbidden", "player ownership mismatch", 403);
      const idx = getPlayerIndex(match, body.playerId);
      if (idx === -1) return err("not_found", "player not in match", 404);
      const player = match.players[idx];
      if (!player) return err("internal_error", "player slot missing", 500);
      match.players[idx] = { ...player, connected: true };
      touchMatch(match);
      return json({ ok: true, match: cloneSnapshot(match) });
    }

    if (method === "GET" && path === "/v1/ws") {
      const matchId = url.searchParams.get("matchId");
      const playerId = url.searchParams.get("playerId");
      const token = url.searchParams.get("token");
      if (!matchId || !playerId || !token) return err("invalid_request", "matchId/playerId/token required", 400);
      const session = playerSessions.get(playerId);
      if (!session || session.token !== token) return err("unauthorized", "invalid websocket auth", 401);
      const match = getMatch(matchId);
      if (!match) return err("not_found", "match not found", 404);
      if (getPlayerIndex(match, playerId) === -1) return err("forbidden", "player not in match", 403);
      const upgraded = serverRef.upgrade(req, { data: { matchId, playerId } });
      if (!upgraded) return err("upgrade_failed", "websocket upgrade failed", 400);
      return new Response(null);
    }

    return err("not_found", "route not found", 404);
  },
  websocket: {
    open(ws) {
      const { matchId, playerId } = ws.data;
      const set = socketsByMatch.get(matchId) ?? new Set<Bun.ServerWebSocket<WsData>>();
      set.add(ws);
      socketsByMatch.set(matchId, set);
      const match = getMatch(matchId);
      if (!match) {
        wsSend(ws, { type: "error", code: "not_found", message: "match not found" });
        ws.close();
        return;
      }
      const idx = getPlayerIndex(match, playerId);
      if (idx >= 0) {
        const player = match.players[idx];
        if (player) match.players[idx] = { ...player, connected: true };
        touchMatch(match);
      }
      wsSend(ws, { type: "state_snapshot", match: cloneSnapshot(match) });
      broadcastSnapshot(match, "lobby_updated");
    },
    message(ws, rawMessage) {
      let parsed: ClientEvent | null = null;
      try {
        parsed = JSON.parse(String(rawMessage)) as ClientEvent;
      } catch {
        wsSend(ws, { type: "error", code: "invalid_json", message: "malformed websocket payload" });
        return;
      }
      if (!parsed || typeof parsed !== "object" || typeof parsed.type !== "string") {
        wsSend(ws, { type: "error", code: "invalid_event", message: "invalid event envelope" });
        return;
      }
      if (parsed.type === "ping") {
        const match = getMatch(ws.data.matchId);
        if (match) wsSend(ws, { type: "state_snapshot", match: cloneSnapshot(match) });
        return;
      }
      if (parsed.type === "client_ready") {
        const match = getMatch(ws.data.matchId);
        if (match) wsSend(ws, { type: "state_snapshot", match: cloneSnapshot(match) });
        return;
      }
      if (parsed.type === "ack") return;
      wsSend(ws, { type: "error", code: "unsupported_event", message: "unsupported client event" });
    },
    close(ws) {
      const { matchId, playerId } = ws.data;
      const set = socketsByMatch.get(matchId);
      if (set) {
        set.delete(ws);
        if (set.size === 0) socketsByMatch.delete(matchId);
      }
      const match = getMatch(matchId);
      if (!match) return;
      applyDisconnect(match, playerId);
    },
  },
});

console.log(`Backend listening on http://localhost:${server.port}`);