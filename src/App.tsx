import {
  Activity,
  CalendarDays,
  CheckCircle2,
  CircleDot,
  ClipboardList,
  LockKeyhole,
  Loader2,
  LogOut,
  Medal,
  Radio,
  RotateCcw,
  Save,
  Trophy,
  UserRound,
  UsersRound,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { isSupabaseConfigured } from "./lib/supabase";
import {
  TOTAL_ROUNDS,
  formatTeam,
  getMatchOutcome,
  getRestingPlayers,
} from "./lib/tournament";
import { useHashRoute } from "./hooks/useHashRoute";
import { useTournament } from "./hooks/useTournament";
import type { HydratedMatch, Player, Standing } from "./types";

type AppRoute = "home" | "schedule" | "scoring" | "rankings" | "player";

const navItems = [
  { label: "Home", href: "#/", route: "home", icon: Activity },
  { label: "Schedule", href: "#/schedule", route: "schedule", icon: CalendarDays },
  { label: "Scoring", href: "#/scoring", route: "scoring", icon: ClipboardList },
  { label: "Rankings", href: "#/rankings", route: "rankings", icon: Trophy },
] as const;

const posterAssetUrl = `${import.meta.env.BASE_URL}beach-not-pro-poster.png`;

function parseRoute(route: string): { page: AppRoute; playerId?: string } {
  if (route.startsWith("/players/")) {
    return { page: "player", playerId: route.replace("/players/", "") };
  }

  if (route === "/schedule") return { page: "schedule" };
  if (route === "/scoring") return { page: "scoring" };
  if (route === "/rankings") return { page: "rankings" };
  return { page: "home" };
}

function classNames(...classes: Array<string | false | null | undefined>) {
  return classes.filter(Boolean).join(" ");
}

function genderLabel(gender: Player["gender"]) {
  return gender === "men" ? "M" : "F";
}

export default function App() {
  const route = useHashRoute();
  const activeRoute = parseRoute(route);
  const tournament = useTournament();
  const currentRound = tournament.tournamentState?.current_round ?? 1;
  const [adminPassword, setAdminPassword] = useState("");
  const [isAdmin, setIsAdmin] = useState(false);
  const [adminMessage, setAdminMessage] = useState<string | null>(null);
  const [isResetting, setIsResetting] = useState(false);

  const currentMatches = useMemo(
    () =>
      tournament.matches.filter((match) => match.round_number === currentRound),
    [currentRound, tournament.matches],
  );

  if (!isSupabaseConfigured) {
    return <SetupRequired />;
  }

  function unlockAdmin() {
    if (adminPassword === "hihi") {
      setIsAdmin(true);
      setAdminMessage("Admin mode unlocked.");
      return;
    }

    setIsAdmin(false);
    setAdminMessage("Wrong password.");
  }

  function lockAdmin() {
    setIsAdmin(false);
    setAdminPassword("");
    setAdminMessage("Admin mode locked.");
  }

  async function resetTournament() {
    if (!isAdmin) {
      setAdminMessage("Unlock admin mode first.");
      return;
    }

    setIsResetting(true);
    setAdminMessage(null);

    try {
      await tournament.resetTournament(adminPassword);
      setAdminMessage("Tournament reset to 0-0.");
    } catch (resetError) {
      setAdminMessage(
        resetError instanceof Error ? resetError.message : "Reset failed.",
      );
    } finally {
      setIsResetting(false);
    }
  }

  return (
    <div className="min-h-screen poster-bg text-zinc-100">
      <header className="border-b border-yellow-400/25 bg-black/95 text-white shadow-court">
        <div className="mx-auto flex max-w-6xl flex-col gap-5 px-4 py-5 sm:px-6 lg:px-8">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <a className="flex items-center gap-3" href="#/">
              <span className="grid h-11 w-11 place-items-center rounded-sm bg-yellow-400 text-black shadow-court">
                <Trophy size={22} aria-hidden="true" />
              </span>
              <span>
                <span className="block text-xl font-black uppercase tracking-normal sm:text-2xl">
                  Beach Not Pro Tour
                </span>
                <span className="text-sm font-bold uppercase text-yellow-200">
                  Single tournament live dashboard
                </span>
              </span>
            </a>
            <div className="poster-pill flex items-center gap-2 rounded-full px-3 py-2 text-sm font-black uppercase">
              <Radio size={16} className="text-yellow-300" aria-hidden="true" />
              <span>Live via Supabase</span>
            </div>
          </div>

          <nav className="grid grid-cols-4 gap-2" aria-label="Primary navigation">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isActive = activeRoute.page === item.route;
              return (
                <a
                  key={item.href}
                  href={item.href}
                  className={classNames(
                    "flex min-h-12 flex-col items-center justify-center gap-1 rounded-sm border px-2 py-2 text-xs font-black uppercase transition sm:min-h-10 sm:flex-row sm:text-sm",
                    isActive
                      ? "border-yellow-300 bg-yellow-400 text-black shadow-court"
                      : "border-white/10 bg-white/5 text-zinc-200 hover:border-yellow-300/70 hover:bg-yellow-400/10 hover:text-yellow-100",
                  )}
                >
                  <Icon size={18} aria-hidden="true" />
                  <span>{item.label}</span>
                </a>
              );
            })}
          </nav>

          <AdminControls
            adminMessage={adminMessage}
            adminPassword={adminPassword}
            isAdmin={isAdmin}
            isResetting={isResetting}
            onAdminPasswordChange={setAdminPassword}
            onLock={lockAdmin}
            onReset={() => void resetTournament()}
            onUnlock={unlockAdmin}
          />
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8">
        {tournament.error ? <ErrorBanner message={tournament.error} /> : null}
        {tournament.isLoading ? (
          <LoadingState />
        ) : (
          <>
            {activeRoute.page === "home" ? (
              <HomePage
                currentRound={currentRound}
                currentMatches={currentMatches}
                completedMatches={tournament.completedMatches}
                totalMatches={tournament.totalMatches}
                progress={tournament.progress}
                standings={tournament.standings}
                lastUpdated={tournament.lastUpdated}
              />
            ) : null}
            {activeRoute.page === "schedule" ? (
              <SchedulePage
                currentRound={currentRound}
                matches={tournament.matches}
                players={tournament.players}
              />
            ) : null}
            {activeRoute.page === "scoring" ? (
              <ScoringPage
                adminPassword={adminPassword}
                currentRound={currentRound}
                isAdmin={isAdmin}
                matches={tournament.matches}
                onSaveScore={tournament.saveScore}
              />
            ) : null}
            {activeRoute.page === "rankings" ? (
              <RankingsPage standings={tournament.standings} />
            ) : null}
            {activeRoute.page === "player" ? (
              <PlayerPage
                playerId={activeRoute.playerId}
                players={tournament.players}
                matches={tournament.matches}
                standings={tournament.standings}
              />
            ) : null}
          </>
        )}
      </main>
    </div>
  );
}

function AdminControls({
  adminMessage,
  adminPassword,
  isAdmin,
  isResetting,
  onAdminPasswordChange,
  onLock,
  onReset,
  onUnlock,
}: {
  adminMessage: string | null;
  adminPassword: string;
  isAdmin: boolean;
  isResetting: boolean;
  onAdminPasswordChange: (value: string) => void;
  onLock: () => void;
  onReset: () => void;
  onUnlock: () => void;
}) {
  return (
    <div className="rounded-md border border-yellow-400/20 bg-white/5 p-3">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-2 text-sm font-black uppercase text-yellow-100">
          <LockKeyhole size={17} className="text-yellow-300" aria-hidden="true" />
          <span>{isAdmin ? "Admin mode on" : "Admin mode"}</span>
        </div>

        {isAdmin ? (
          <div className="flex flex-col gap-2 sm:flex-row">
            <button
              type="button"
              onClick={onReset}
              disabled={isResetting}
              className="inline-flex min-h-10 items-center justify-center gap-2 rounded-sm bg-yellow-400 px-4 py-2 text-sm font-black uppercase text-black transition hover:bg-yellow-300 disabled:cursor-not-allowed disabled:opacity-60"
              title="Reset tournament"
            >
              {isResetting ? (
                <Loader2 className="animate-spin" size={16} aria-hidden="true" />
              ) : (
                <RotateCcw size={16} aria-hidden="true" />
              )}
              Reset Game
            </button>
            <button
              type="button"
              onClick={onLock}
              className="inline-flex min-h-10 items-center justify-center gap-2 rounded-sm border border-white/15 px-4 py-2 text-sm font-black uppercase text-white transition hover:border-yellow-300/70 hover:text-yellow-100"
              title="Lock admin mode"
            >
              <LogOut size={16} aria-hidden="true" />
              Lock
            </button>
          </div>
        ) : (
          <div className="grid gap-2 sm:grid-cols-[180px_auto]">
            <input
              className="h-10 rounded-sm border border-white/15 bg-black px-3 text-sm font-bold text-white placeholder:text-zinc-500"
              type="password"
              value={adminPassword}
              onChange={(event) => onAdminPasswordChange(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") onUnlock();
              }}
              placeholder="Password"
              aria-label="Admin password"
            />
            <button
              type="button"
              onClick={onUnlock}
              className="inline-flex min-h-10 items-center justify-center gap-2 rounded-sm bg-yellow-400 px-4 py-2 text-sm font-black uppercase text-black transition hover:bg-yellow-300"
              title="Unlock admin mode"
            >
              <LockKeyhole size={16} aria-hidden="true" />
              Unlock
            </button>
          </div>
        )}
      </div>

      {adminMessage ? (
        <p className="mt-2 text-sm font-bold text-yellow-100" role="status">
          {adminMessage}
        </p>
      ) : null}
    </div>
  );
}

function SetupRequired() {
  return (
    <div className="poster-bg min-h-screen px-4 py-10 text-white">
      <div className="poster-surface mx-auto max-w-2xl rounded-md p-6 shadow-court">
        <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-sm bg-yellow-400 text-black">
          <CircleDot size={24} aria-hidden="true" />
        </div>
        <h1 className="text-2xl font-black uppercase tracking-normal">
          Connect Supabase
        </h1>
        <p className="mt-2 font-semibold text-zinc-700">
          Add your Supabase URL and anon key to the environment before running the
          tournament dashboard.
        </p>
        <div className="mt-5 rounded-md bg-black p-4 text-sm font-semibold text-yellow-100">
          <div>VITE_SUPABASE_URL=...</div>
          <div>VITE_SUPABASE_ANON_KEY=...</div>
        </div>
      </div>
    </div>
  );
}

function LoadingState() {
  return (
    <div className="poster-card flex min-h-80 items-center justify-center rounded-md shadow-court">
      <div className="relative z-10 flex items-center gap-3 text-yellow-300">
        <Loader2 className="animate-spin" size={24} aria-hidden="true" />
        <span className="font-black uppercase">Loading tournament</span>
      </div>
    </div>
  );
}

function ErrorBanner({ message }: { message: string }) {
  return (
    <div className="mb-5 rounded-md border border-yellow-300/50 bg-yellow-400 px-4 py-3 text-sm font-black text-black">
      {message}
    </div>
  );
}

function HomePage({
  currentRound,
  currentMatches,
  completedMatches,
  totalMatches,
  progress,
  standings,
  lastUpdated,
}: {
  currentRound: number;
  currentMatches: HydratedMatch[];
  completedMatches: number;
  totalMatches: number;
  progress: number;
  standings: Array<Standing & { player: Player }>;
  lastUpdated: Date | null;
}) {
  return (
    <div className="space-y-5">
      <section className="poster-hero rounded-md shadow-court">
        <div className="poster-hero-media" aria-hidden="true">
          <img src={posterAssetUrl} alt="" />
        </div>
        <div className="relative z-10 grid gap-6 p-5 sm:p-7 lg:grid-cols-[1fr_320px] lg:p-8">
          <div>
            <div className="poster-pill mb-6 inline-flex items-center gap-2 rounded-full px-3 py-1 text-sm font-black uppercase">
              <CircleDot size={15} className="text-yellow-300" aria-hidden="true" />
              Current Round {currentRound}
            </div>
            <h1 className="poster-title max-w-2xl text-6xl tracking-normal sm:text-8xl">
              Beach
              <span className="poster-word-gold">Not Pro</span>
              Tour
            </h1>
            <p className="mt-4 max-w-xl text-base font-black uppercase text-zinc-100 sm:text-lg">
              Mixed 2v2 beach volleyball tournament scoreboard.
            </p>
          </div>
          <div className="poster-surface self-end rounded-md p-5 shadow-court">
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="text-sm font-black uppercase tracking-normal text-zinc-600">
                  Tournament Progress
                </p>
                <p className="mt-1 text-4xl font-black text-black">
                  {completedMatches}/{totalMatches}
                </p>
              </div>
              <div className="grid h-16 w-16 place-items-center rounded-sm bg-black text-lg font-black text-yellow-300">
                {progress}%
              </div>
            </div>
            <div className="mt-5 h-3 overflow-hidden rounded-full bg-zinc-200">
              <div
                className="h-full rounded-full bg-yellow-400 transition-all"
                style={{ width: `${progress}%` }}
              />
            </div>
            <p className="mt-4 text-sm font-black uppercase text-zinc-600">
              Last synced {lastUpdated ? lastUpdated.toLocaleTimeString() : "just now"}
            </p>
          </div>
        </div>
      </section>

      <div className="grid gap-5 lg:grid-cols-[1.15fr_0.85fr]">
        <section className="poster-surface rounded-md p-5 shadow-court">
          <SectionHeader icon={ClipboardList} title="Current Matches" />
          <div className="mt-4 space-y-3">
            {currentMatches.map((match) => (
              <MatchRow key={match.id} match={match} highlighted />
            ))}
          </div>
        </section>

        <section className="poster-surface rounded-md p-5 shadow-court">
          <SectionHeader icon={Medal} title="Current Leaders" />
          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            <LeaderList
              title="Men"
              standings={standings.filter((standing) => standing.player.gender === "men").slice(0, 3)}
            />
            <LeaderList
              title="Women"
              standings={standings.filter((standing) => standing.player.gender === "women").slice(0, 3)}
            />
          </div>
        </section>
      </div>
    </div>
  );
}

function SchedulePage({
  currentRound,
  matches,
  players,
}: {
  currentRound: number;
  matches: HydratedMatch[];
  players: Player[];
}) {
  return (
    <div className="space-y-5">
      <PageTitle
        icon={CalendarDays}
        title="Schedule"
        subtitle="Fixed rounds for the single Beach Not Pro Tour tournament."
      />

      {Array.from({ length: TOTAL_ROUNDS }, (_, index) => index + 1).map((round) => {
        const roundMatches = matches.filter((match) => match.round_number === round);
        const restingPlayers = getRestingPlayers(players, matches, round);
        const isCurrent = round === currentRound;
        const isComplete =
          roundMatches.length > 0 && roundMatches.every((match) => match.completed);

        return (
          <section
            key={round}
            className={classNames(
              "poster-surface rounded-md p-5 shadow-court",
              isCurrent && "ring-2 ring-yellow-400",
              isComplete && "border-yellow-400 bg-yellow-50",
            )}
          >
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="text-xl font-black uppercase tracking-normal text-black">
                  Round {round}
                </h2>
                <p className="text-sm font-black uppercase text-zinc-600">
                  {isCurrent ? "Current round" : isComplete ? "Completed" : "Upcoming"}
                </p>
              </div>
              {isComplete ? (
                <span className="inline-flex items-center gap-2 rounded-full bg-black px-3 py-1 text-sm font-black uppercase text-yellow-300">
                  <CheckCircle2 size={16} aria-hidden="true" />
                  Complete
                </span>
              ) : null}
            </div>

            <div className="mt-4 grid gap-3 lg:grid-cols-3">
              {roundMatches.map((match) => (
                <MatchRow key={match.id} match={match} compact />
              ))}
            </div>

            <div className="mt-4 rounded-md border border-yellow-900/15 bg-black px-3 py-2 text-sm font-black uppercase text-yellow-300">
              Resting:{" "}
              <span className="text-white">
                {restingPlayers.map((player) => player.name).join(", ")}
              </span>
            </div>
          </section>
        );
      })}
    </div>
  );
}

function ScoringPage({
  adminPassword,
  currentRound,
  isAdmin,
  matches,
  onSaveScore,
}: {
  adminPassword: string;
  currentRound: number;
  isAdmin: boolean;
  matches: HydratedMatch[];
  onSaveScore: (
    matchId: string,
    scoreA: number,
    scoreB: number,
    adminPassword: string,
  ) => Promise<void>;
}) {
  return (
    <div className="space-y-5">
      <PageTitle
        icon={ClipboardList}
        title="Live Scoring"
        subtitle={
          isAdmin
            ? "Admin mode is on. Saved scores update every open browser."
            : "Unlock admin mode above to change scores."
        }
      />
      {Array.from({ length: TOTAL_ROUNDS }, (_, index) => index + 1).map((round) => (
        <section
          key={round}
          className={classNames(
            "poster-surface rounded-md p-5 shadow-court",
            round === currentRound && "ring-2 ring-yellow-400",
          )}
        >
          <h2 className="text-xl font-black uppercase tracking-normal text-black">
            Round {round}
          </h2>
          <div className="mt-4 grid gap-4 lg:grid-cols-3">
            {matches
              .filter((match) => match.round_number === round)
              .map((match) => (
                <ScoreCard
                  key={match.id}
                  adminPassword={adminPassword}
                  isAdmin={isAdmin}
                  match={match}
                  onSaveScore={onSaveScore}
                />
              ))}
          </div>
        </section>
      ))}
    </div>
  );
}

function RankingsPage({
  standings,
}: {
  standings: Array<Standing & { player: Player }>;
}) {
  const mensStandings = standings.filter((standing) => standing.player.gender === "men");
  const womensStandings = standings.filter(
    (standing) => standing.player.gender === "women",
  );

  return (
    <div className="space-y-5">
      <PageTitle
        icon={Trophy}
        title="Rankings"
        subtitle="Men and women are ranked separately by wins, then point differential."
      />
      <div className="grid gap-5 lg:grid-cols-2">
        <RankingTable title="Men" standings={mensStandings} />
        <RankingTable title="Women" standings={womensStandings} />
      </div>
    </div>
  );
}

function RankingTable({
  title,
  standings,
}: {
  title: string;
  standings: Array<Standing & { player: Player }>;
}) {
  return (
    <section className="poster-surface overflow-hidden rounded-md shadow-court">
      <div className="flex items-center justify-between gap-3 bg-black px-4 py-3">
        <h2 className="text-xl font-black uppercase tracking-normal text-white">
          {title}
        </h2>
        <span className="rounded-full bg-yellow-400 px-3 py-1 text-xs font-black uppercase text-black">
          {standings.length} players
        </span>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full min-w-[520px] border-collapse text-left">
          <thead className="bg-zinc-950 text-sm uppercase text-yellow-300">
            <tr>
              <th className="px-4 py-3 font-black">Rank</th>
              <th className="px-4 py-3 font-black">Player</th>
              <th className="px-4 py-3 font-black">Wins</th>
              <th className="px-4 py-3 font-black">Losses</th>
              <th className="px-4 py-3 font-black">Diff</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-yellow-900/15">
            {standings.map((standing, index) => (
              <tr key={standing.player_id} className="hover:bg-yellow-100/70">
                <td className="px-4 py-4 text-lg font-black text-yellow-700">
                  {index + 1}
                </td>
                <td className="px-4 py-4">
                  <a
                    href={`#/players/${standing.player_id}`}
                    className="inline-flex items-center gap-2 font-black text-black hover:text-yellow-700"
                  >
                    <UserRound size={18} aria-hidden="true" />
                    {standing.player.name}
                  </a>
                  <div className="text-xs font-black uppercase tracking-normal text-zinc-500">
                    {genderLabel(standing.player.gender)}
                  </div>
                </td>
                <td className="px-4 py-4 font-black text-black">{standing.wins}</td>
                <td className="px-4 py-4 font-black text-zinc-600">
                  {standing.losses}
                </td>
                <td
                  className={classNames(
                    "px-4 py-4 font-black",
                    standing.point_differential >= 0
                      ? "text-yellow-700"
                      : "text-red-700",
                  )}
                >
                  {standing.point_differential > 0 ? "+" : ""}
                  {standing.point_differential}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function PlayerPage({
  playerId,
  players,
  matches,
  standings,
}: {
  playerId?: string;
  players: Player[];
  matches: HydratedMatch[];
  standings: Array<Standing & { player: Player }>;
}) {
  const player = players.find((candidate) => candidate.id === playerId);
  const standing = standings.find((candidate) => candidate.player_id === playerId);

  const playerMatches = matches.filter(
    (match) =>
      match.team_a_player_1 === playerId ||
      match.team_a_player_2 === playerId ||
      match.team_b_player_1 === playerId ||
      match.team_b_player_2 === playerId,
  );

  const partnerCounts = new Map<string, { player: Player; count: number }>();
  playerMatches.forEach((match) => {
    if (!playerId) return;
    const isTeamA =
      match.team_a_player_1 === playerId || match.team_a_player_2 === playerId;
    const partner = isTeamA
      ? match.teamA.player1.id === playerId
        ? match.teamA.player2
        : match.teamA.player1
      : match.teamB.player1.id === playerId
        ? match.teamB.player2
        : match.teamB.player1;
    const current = partnerCounts.get(partner.id);
    partnerCounts.set(partner.id, {
      player: partner,
      count: (current?.count ?? 0) + 1,
    });
  });

  if (!player) {
    return (
      <section className="poster-surface rounded-md p-6 shadow-court">
        <h1 className="text-2xl font-black uppercase tracking-normal">Player not found</h1>
        <a className="mt-3 inline-block font-black text-yellow-700" href="#/rankings">
          Back to rankings
        </a>
      </section>
    );
  }

  return (
    <div className="space-y-5">
      <PageTitle
        icon={UserRound}
        title={player.name}
        subtitle={genderLabel(player.gender)}
      />

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Record" value={`${standing?.wins ?? 0}-${standing?.losses ?? 0}`} />
        <StatCard label="Matches Played" value={standing?.matches_played ?? 0} />
        <StatCard
          label="Point Differential"
          value={`${(standing?.point_differential ?? 0) > 0 ? "+" : ""}${
            standing?.point_differential ?? 0
          }`}
        />
        <StatCard label="Partners" value={partnerCounts.size} />
      </section>

      <section className="poster-surface rounded-md p-5 shadow-court">
        <SectionHeader icon={UsersRound} title="Partners" />
        <div className="mt-4 flex flex-wrap gap-2">
          {Array.from(partnerCounts.values()).map(({ player: partner, count }) => (
            <span
              key={partner.id}
              className="rounded-full bg-black px-3 py-1 text-sm font-black uppercase text-yellow-300"
            >
              {partner.name} × {count}
            </span>
          ))}
        </div>
      </section>

      <section className="poster-surface rounded-md p-5 shadow-court">
        <SectionHeader icon={ClipboardList} title="Results" />
        <div className="mt-4 space-y-3">
          {playerMatches.map((match) => {
            const isTeamA =
              match.team_a_player_1 === player.id || match.team_a_player_2 === player.id;
            const partner = isTeamA
              ? match.teamA.player1.id === player.id
                ? match.teamA.player2
                : match.teamA.player1
              : match.teamB.player1.id === player.id
                ? match.teamB.player2
                : match.teamB.player1;

            return (
              <div
                key={match.id}
                className="rounded-md border border-yellow-900/15 bg-white/80 px-4 py-3"
              >
                <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <div className="text-sm font-black uppercase text-black">
                      Round {match.round_number} · Court {match.court_number}
                    </div>
                    <div className="mt-1 text-sm font-bold text-zinc-700">
                      Partner: {partner.name}
                    </div>
                    <div className="mt-1 text-sm font-bold text-zinc-700">
                      {formatTeam(match, "A")} vs {formatTeam(match, "B")}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      className={classNames(
                        "rounded-full px-3 py-1 text-sm font-black",
                        getMatchOutcome(match, player.id) === "Win"
                          ? "bg-black text-yellow-300"
                          : getMatchOutcome(match, player.id) === "Loss"
                            ? "bg-red-100 text-red-700"
                            : "bg-zinc-200 text-zinc-700",
                      )}
                    >
                      {getMatchOutcome(match, player.id)}
                    </span>
                    <span className="font-black text-black">
                      {match.score_a ?? "-"} : {match.score_b ?? "-"}
                    </span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </section>
    </div>
  );
}

function ScoreCard({
  adminPassword,
  isAdmin,
  match,
  onSaveScore,
}: {
  adminPassword: string;
  isAdmin: boolean;
  match: HydratedMatch;
  onSaveScore: (
    matchId: string,
    scoreA: number,
    scoreB: number,
    adminPassword: string,
  ) => Promise<void>;
}) {
  const [scoreA, setScoreA] = useState(match.score_a?.toString() ?? "");
  const [scoreB, setScoreB] = useState(match.score_b?.toString() ?? "");
  const [isSaving, setIsSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    setScoreA(match.score_a?.toString() ?? "");
    setScoreB(match.score_b?.toString() ?? "");
  }, [match.score_a, match.score_b]);

  const parsedA = Number(scoreA);
  const parsedB = Number(scoreB);
  const canSave =
    scoreA.trim() !== "" &&
    scoreB.trim() !== "" &&
    Number.isInteger(parsedA) &&
    Number.isInteger(parsedB) &&
    parsedA >= 0 &&
    parsedB >= 0 &&
    parsedA !== parsedB;

  async function handleSave() {
    if (!isAdmin) {
      setMessage("Unlock admin mode to save scores.");
      return;
    }

    if (!canSave) {
      setMessage("Enter two non-tied whole-number scores.");
      return;
    }

    setIsSaving(true);
    setMessage(null);

    try {
      await onSaveScore(match.id, parsedA, parsedB, adminPassword);
      setMessage("Saved live.");
    } catch (saveError) {
      setMessage(saveError instanceof Error ? saveError.message : "Score was not saved.");
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <article className="poster-card rounded-md p-4 text-white">
      <div className="mb-4 flex items-center justify-between gap-3">
        <span className="relative z-10 rounded-sm bg-yellow-400 px-3 py-1 text-sm font-black uppercase text-black">
          Court {match.court_number}
        </span>
        <span
          className={classNames(
            "relative z-10 rounded-full px-3 py-1 text-xs font-black uppercase",
            match.completed
              ? "bg-white text-black"
              : "bg-yellow-400/20 text-yellow-200",
          )}
        >
          {match.completed ? "Completed" : "Open"}
        </span>
      </div>

      <ScoreInput
        label="Team A"
        team={formatTeam(match, "A")}
        value={scoreA}
        onChange={setScoreA}
        readOnly={!isAdmin}
      />
      <div className="relative z-10 my-3 h-px bg-yellow-400/20" />
      <ScoreInput
        label="Team B"
        team={formatTeam(match, "B")}
        value={scoreB}
        onChange={setScoreB}
        readOnly={!isAdmin}
      />

      <button
        type="button"
        onClick={() => void handleSave()}
        disabled={isSaving || !isAdmin}
        className="relative z-10 mt-4 inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-sm bg-yellow-400 px-4 py-2 font-black uppercase text-black transition hover:bg-yellow-300 disabled:cursor-not-allowed disabled:opacity-60"
        title="Save score"
      >
        {isSaving ? (
          <Loader2 className="animate-spin" size={18} aria-hidden="true" />
        ) : (
          <Save size={18} aria-hidden="true" />
        )}
        {isAdmin ? "Save" : "Admin Locked"}
      </button>

      {message ? (
        <p className="relative z-10 mt-3 text-sm font-black uppercase text-yellow-100" role="status">
          {message}
        </p>
      ) : null}
    </article>
  );
}

function ScoreInput({
  label,
  readOnly,
  team,
  value,
  onChange,
}: {
  label: string;
  readOnly: boolean;
  team: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="relative z-10 grid grid-cols-[1fr_84px] items-center gap-3">
      <span>
        <span className="block text-xs font-black uppercase tracking-normal text-yellow-300">
          {label}
        </span>
        <span className="block text-sm font-black text-white">{team}</span>
      </span>
      <input
        className="h-12 w-full rounded-sm border border-yellow-400/40 bg-white px-3 text-center text-xl font-black text-black"
        inputMode="numeric"
        min={0}
        readOnly={readOnly}
        type="number"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        aria-label={`${label} score`}
      />
    </label>
  );
}

function MatchRow({
  match,
  compact = false,
  highlighted = false,
}: {
  match: HydratedMatch;
  compact?: boolean;
  highlighted?: boolean;
}) {
  return (
    <div
      className={classNames(
        "rounded-md border px-4 py-3 shadow-sm",
        match.completed
          ? "border-yellow-400 bg-black text-white"
          : highlighted
            ? "border-yellow-400 bg-yellow-100 text-black"
            : "border-yellow-900/15 bg-white/80 text-black",
      )}
    >
      <div className="mb-2 flex items-center justify-between gap-3">
        <span className={classNames("text-sm font-black uppercase", match.completed ? "text-yellow-300" : "text-yellow-700")}>
          Court {match.court_number}
        </span>
        <span
          className={classNames(
            "rounded-full px-2 py-1 text-xs font-black uppercase",
            match.completed
              ? "bg-yellow-400 text-black"
              : "bg-black text-yellow-300",
          )}
        >
          {match.completed ? "Done" : "Live"}
        </span>
      </div>
      <div className={classNames("grid gap-2", compact ? "text-sm" : "text-base")}>
        <TeamLine
          name={formatTeam(match, "A")}
          score={match.score_a}
          winner={
            match.completed &&
            match.score_a !== null &&
            match.score_b !== null &&
            match.score_a > match.score_b
          }
        />
        <TeamLine
          name={formatTeam(match, "B")}
          score={match.score_b}
          winner={
            match.completed &&
            match.score_a !== null &&
            match.score_b !== null &&
            match.score_b > match.score_a
          }
        />
      </div>
    </div>
  );
}

function TeamLine({
  name,
  score,
  winner,
}: {
  name: string;
  score: number | null;
  winner: boolean;
}) {
  return (
    <div className="grid grid-cols-[1fr_auto] items-center gap-3">
      <span
        className={classNames(
          "font-black tracking-normal",
          winner ? "text-yellow-500" : "text-inherit",
        )}
      >
        {name}
      </span>
      <span className="min-w-8 text-right text-lg font-black text-inherit">
        {score ?? "-"}
      </span>
    </div>
  );
}

function RankingStrip({
  standing,
  rank,
}: {
  standing: Standing & { player: Player };
  rank: number;
}) {
  return (
    <a
      href={`#/players/${standing.player_id}`}
      className="grid grid-cols-[40px_1fr_auto] items-center gap-3 py-3 hover:text-yellow-700"
    >
      <span className="grid h-9 w-9 place-items-center rounded-sm bg-black font-black text-yellow-300">
        {rank}
      </span>
      <span>
        <span className="block font-black text-black">{standing.player.name}</span>
        <span className="text-sm font-black uppercase text-zinc-600">
          {standing.wins}W · {standing.losses}L
        </span>
      </span>
      <span
        className={classNames(
          "font-black",
          standing.point_differential >= 0 ? "text-yellow-700" : "text-red-700",
        )}
      >
        {standing.point_differential > 0 ? "+" : ""}
        {standing.point_differential}
      </span>
    </a>
  );
}

function LeaderList({
  title,
  standings,
}: {
  title: string;
  standings: Array<Standing & { player: Player }>;
}) {
  return (
    <div>
      <h3 className="text-sm font-black uppercase text-zinc-600">{title}</h3>
      <div className="mt-2 divide-y divide-yellow-900/15">
        {standings.map((standing, index) => (
          <RankingStrip key={standing.player_id} standing={standing} rank={index + 1} />
        ))}
      </div>
    </div>
  );
}

function PageTitle({
  icon: Icon,
  title,
  subtitle,
}: {
  icon: typeof Trophy;
  title: string;
  subtitle: string;
}) {
  return (
    <div className="flex items-start gap-3">
      <span className="grid h-11 w-11 place-items-center rounded-sm bg-yellow-400 text-black shadow-court">
        <Icon size={21} aria-hidden="true" />
      </span>
      <div>
        <h1 className="text-2xl font-black uppercase tracking-normal text-white sm:text-3xl">
          {title}
        </h1>
        <p className="mt-1 text-sm font-black uppercase text-yellow-200">{subtitle}</p>
      </div>
    </div>
  );
}

function SectionHeader({
  icon: Icon,
  title,
}: {
  icon: typeof Trophy;
  title: string;
}) {
  return (
    <div className="flex items-center gap-2">
      <Icon size={20} className="text-yellow-600" aria-hidden="true" />
      <h2 className="text-lg font-black uppercase tracking-normal text-black">
        {title}
      </h2>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="poster-surface rounded-md p-5 shadow-court">
      <p className="text-sm font-black uppercase tracking-normal text-zinc-600">
        {label}
      </p>
      <p className="mt-2 text-3xl font-black text-black">{value}</p>
    </div>
  );
}
