export function parsePowermetricsText(text) {
  const sections = splitSamples(text);
  const samples = [];

  for (const section of sections) {
    const combined = readPower(section, [
      /(?:Combined|Total)[^\n:]*Power[^\n:]*:\s*([0-9.]+)\s*(mW|W)\b/i,
      /CPU \+ GPU \+ ANE Power:\s*([0-9.]+)\s*(mW|W)\b/i,
    ]);
    const cpu = readPower(section, [/^CPU Power:\s*([0-9.]+)\s*(mW|W)\b/im]);
    const gpu = readPower(section, [/^GPU Power:\s*([0-9.]+)\s*(mW|W)\b/im]);
    const ane = readPower(section, [/^ANE Power:\s*([0-9.]+)\s*(mW|W)\b/im]);
    const summed = finiteSum([cpu, gpu, ane]);

    if (Number.isFinite(combined) || Number.isFinite(summed)) {
      samples.push({
        cpuPowerMilliwatts: Number.isFinite(cpu) ? cpu : null,
        gpuPowerMilliwatts: Number.isFinite(gpu) ? gpu : null,
        anePowerMilliwatts: Number.isFinite(ane) ? ane : null,
        estimatedSocPowerMilliwatts: Number.isFinite(combined) ? combined : summed,
      });
    }
  }

  return samples;
}

export function summarizePowerSamples(samples, durationMilliseconds, idleAverageMilliwatts = 0) {
  const averageEstimatedSocPowerMilliwatts = average(
    samples.map((sample) => sample.estimatedSocPowerMilliwatts).filter(Number.isFinite),
  );
  const durationSeconds = durationMilliseconds / 1000;
  const grossEstimatedSocEnergyJoules = (averageEstimatedSocPowerMilliwatts * durationSeconds) / 1000;
  const idleAdjustedEstimatedSocEnergyJoules = Math.max(
    0,
    ((averageEstimatedSocPowerMilliwatts - idleAverageMilliwatts) * durationSeconds) / 1000,
  );

  return {
    sampleCount: samples.length,
    durationMilliseconds,
    averageEstimatedSocPowerMilliwatts,
    idleAverageMilliwatts,
    grossEstimatedSocEnergyJoules,
    idleAdjustedEstimatedSocEnergyJoules,
  };
}

function splitSamples(text) {
  const parts = String(text)
    .split(/(?=^\*\*\* Sampled|^Sampled system activity|^Power stats for)/gim)
    .map((part) => part.trim())
    .filter(Boolean);

  return parts.length ? parts : [String(text)];
}

function readPower(section, patterns) {
  for (const pattern of patterns) {
    const match = section.match(pattern);
    if (!match) continue;

    const value = Number.parseFloat(match[1]);
    if (!Number.isFinite(value)) continue;

    return match[2].toLowerCase() === "w" ? value * 1000 : value;
  }

  return null;
}

function finiteSum(values) {
  const finiteValues = values.filter(Number.isFinite);
  if (!finiteValues.length) return null;
  return finiteValues.reduce((total, value) => total + value, 0);
}

function average(values) {
  if (!values.length) return null;
  return values.reduce((total, value) => total + value, 0) / values.length;
}
