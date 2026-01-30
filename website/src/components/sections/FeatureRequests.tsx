"use client";

import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { FadeIn } from "../effects/FadeIn";

interface FeatureRequest {
  id: string;
  title: string;
  votes: number;
  createdAt: string;
  voted?: boolean;
}

const STORAGE_KEY = "superclip-features";
const VOTE_KEY = "superclip-votes";
const RATE_LIMIT_KEY = "superclip-rate-limit";
const RATE_LIMIT_MS = 60_000; // 1 request per minute

function generateId() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

function getStoredFeatures(): FeatureRequest[] {
  if (typeof window === "undefined") return [];
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored ? JSON.parse(stored) : getDefaultFeatures();
  } catch {
    return getDefaultFeatures();
  }
}

function getDefaultFeatures(): FeatureRequest[] {
  return [
    { id: "default-1", title: "Snippet templates with variables", votes: 24, createdAt: "2026-01-28" },
    { id: "default-2", title: "Sync clipboard across Macs via iCloud", votes: 19, createdAt: "2026-01-27" },
    { id: "default-3", title: "Custom themes and color schemes", votes: 15, createdAt: "2026-01-26" },
    { id: "default-4", title: "Clipboard rules (auto-format, auto-clean URLs)", votes: 12, createdAt: "2026-01-25" },
    { id: "default-5", title: "Raycast / Alfred integration", votes: 9, createdAt: "2026-01-24" },
  ];
}

function getVotedIds(): Set<string> {
  if (typeof window === "undefined") return new Set();
  try {
    const stored = localStorage.getItem(VOTE_KEY);
    return stored ? new Set(JSON.parse(stored)) : new Set();
  } catch {
    return new Set();
  }
}

function checkRateLimit(): boolean {
  if (typeof window === "undefined") return false;
  try {
    const last = localStorage.getItem(RATE_LIMIT_KEY);
    if (!last) return true;
    return Date.now() - parseInt(last) > RATE_LIMIT_MS;
  } catch {
    return true;
  }
}

export function FeatureRequests() {
  const [features, setFeatures] = useState<FeatureRequest[]>([]);
  const [votedIds, setVotedIds] = useState<Set<string>>(new Set());
  const [newTitle, setNewTitle] = useState("");
  const [submitState, setSubmitState] = useState<"idle" | "success" | "rate-limited">("idle");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    setFeatures(getStoredFeatures());
    setVotedIds(getVotedIds());
  }, []);

  const saveFeatures = useCallback((updated: FeatureRequest[]) => {
    setFeatures(updated);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
  }, []);

  const saveVotedIds = useCallback((ids: Set<string>) => {
    setVotedIds(ids);
    localStorage.setItem(VOTE_KEY, JSON.stringify([...ids]));
  }, []);

  const handleVote = useCallback(
    (id: string) => {
      if (votedIds.has(id)) return;

      const updated = features
        .map((f) => (f.id === id ? { ...f, votes: f.votes + 1 } : f))
        .sort((a, b) => b.votes - a.votes);
      saveFeatures(updated);

      const newVoted = new Set(votedIds);
      newVoted.add(id);
      saveVotedIds(newVoted);
    },
    [features, votedIds, saveFeatures, saveVotedIds]
  );

  const handleSubmit = useCallback(
    (e: React.FormEvent) => {
      e.preventDefault();
      const trimmed = newTitle.trim();
      if (!trimmed) return;

      if (!checkRateLimit()) {
        setSubmitState("rate-limited");
        setTimeout(() => setSubmitState("idle"), 3000);
        return;
      }

      const newFeature: FeatureRequest = {
        id: generateId(),
        title: trimmed,
        votes: 1,
        createdAt: new Date().toISOString().split("T")[0],
      };

      const updated = [newFeature, ...features].sort(
        (a, b) => b.votes - a.votes
      );
      saveFeatures(updated);

      const newVoted = new Set(votedIds);
      newVoted.add(newFeature.id);
      saveVotedIds(newVoted);

      localStorage.setItem(RATE_LIMIT_KEY, Date.now().toString());
      setNewTitle("");
      setSubmitState("success");
      setTimeout(() => setSubmitState("idle"), 3000);
    },
    [newTitle, features, votedIds, saveFeatures, saveVotedIds]
  );

  const sorted = [...features].sort((a, b) => b.votes - a.votes);

  return (
    <section id="feature-requests" className="relative py-32">
      <div
        className="pointer-events-none absolute top-0 left-1/2 -translate-x-1/2 h-[1px] w-[600px]"
        style={{
          background:
            "linear-gradient(90deg, transparent, rgba(139,92,246,0.2), transparent)",
        }}
        aria-hidden
      />

      <div className="mx-auto max-w-[var(--container)] px-6">
        <FadeIn>
          <div className="text-center mb-16">
            <p className="text-[13px] font-semibold uppercase tracking-widest text-purple-400/70 mb-4">
              Feature Requests
            </p>
            <h2 className="text-4xl md:text-5xl font-extrabold tracking-tight">
              You decide what&apos;s next
            </h2>
            <p className="mt-4 text-lg text-white/40 max-w-lg mx-auto">
              Submit feature ideas and vote anonymously. The most popular requests shape our roadmap.
            </p>
          </div>
        </FadeIn>

        <div className="max-w-[560px] mx-auto">
          {/* Submit Form */}
          <FadeIn delay={0.1}>
            <form onSubmit={handleSubmit} className="mb-8">
              <div className="glass flex items-center gap-3 p-2 pr-3">
                <input
                  type="text"
                  value={newTitle}
                  onChange={(e) => setNewTitle(e.target.value)}
                  placeholder="Suggest a feature..."
                  maxLength={120}
                  className="flex-1 bg-transparent px-4 py-2.5 text-[14px] text-white/80 placeholder:text-white/25 outline-none"
                />
                <button
                  type="submit"
                  disabled={!newTitle.trim()}
                  className="shrink-0 inline-flex h-9 items-center rounded-lg px-4 text-[13px] font-semibold text-white transition-all duration-200 disabled:opacity-30 disabled:cursor-not-allowed hover:brightness-110"
                  style={{
                    background: newTitle.trim()
                      ? "var(--gradient-primary)"
                      : "rgba(255,255,255,0.06)",
                  }}
                >
                  Submit
                </button>
              </div>

              {/* Feedback Messages */}
              <AnimatePresence>
                {submitState === "success" && (
                  <motion.p
                    initial={{ opacity: 0, y: -4 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0 }}
                    className="mt-2 text-[12px] text-emerald-400 text-center"
                  >
                    Feature submitted! Thanks for your input.
                  </motion.p>
                )}
                {submitState === "rate-limited" && (
                  <motion.p
                    initial={{ opacity: 0, y: -4 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0 }}
                    className="mt-2 text-[12px] text-amber-400 text-center"
                  >
                    Please wait a minute before submitting again.
                  </motion.p>
                )}
              </AnimatePresence>
            </form>
          </FadeIn>

          {/* Feature List */}
          <FadeIn delay={0.2}>
            <div className="space-y-2">
              {mounted &&
                sorted.map((feature, i) => {
                  const hasVoted = votedIds.has(feature.id);

                  return (
                    <motion.div
                      key={feature.id}
                      layout
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ duration: 0.3, delay: i * 0.03 }}
                      className="glass glass-hover flex items-center gap-4 px-5 py-4 transition-all duration-200"
                    >
                      {/* Vote Button */}
                      <button
                        onClick={() => handleVote(feature.id)}
                        disabled={hasVoted}
                        className={`shrink-0 flex flex-col items-center gap-0.5 transition-all duration-200 ${
                          hasVoted
                            ? "cursor-default"
                            : "cursor-pointer hover:scale-110"
                        }`}
                        aria-label={`Vote for ${feature.title}`}
                      >
                        <svg
                          className={`h-4 w-4 transition-colors ${
                            hasVoted ? "text-cyan-400" : "text-white/25 hover:text-cyan-400"
                          }`}
                          fill={hasVoted ? "currentColor" : "none"}
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                          strokeWidth={2}
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            d="M4.5 15.75l7.5-7.5 7.5 7.5"
                          />
                        </svg>
                        <span
                          className={`text-[13px] font-bold tabular-nums ${
                            hasVoted ? "text-cyan-400" : "text-white/40"
                          }`}
                        >
                          {feature.votes}
                        </span>
                      </button>

                      {/* Feature Title */}
                      <span className="text-[14px] text-white/70 leading-snug">
                        {feature.title}
                      </span>

                      {/* Rank indicator for top 3 */}
                      {i < 3 && (
                        <span
                          className={`ml-auto shrink-0 inline-flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-bold ${
                            i === 0
                              ? "bg-amber-400/15 text-amber-400"
                              : i === 1
                                ? "bg-gray-300/15 text-gray-400"
                                : "bg-orange-400/10 text-orange-400/70"
                          }`}
                        >
                          {i + 1}
                        </span>
                      )}
                    </motion.div>
                  );
                })}
            </div>
          </FadeIn>

          <FadeIn delay={0.3}>
            <p className="mt-6 text-center text-[12px] text-white/20">
              All submissions and votes are anonymous. One vote per feature.
            </p>
          </FadeIn>
        </div>
      </div>
    </section>
  );
}
