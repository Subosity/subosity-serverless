import { RRule, Frequency, Options as RRuleOptions } from "https://esm.sh/rrule@2.7.1";

// A straightforward interface for configuring recurrence.
export interface RuleConfig {
  frequency: 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY';
  interval: number;
  byDay?: string[];      // e.g. ['MO', 'TU', 'WE']
  byMonthDay?: number[]; // e.g. [1, 15, -1]
  byMonth?: number[];    // e.g. [1, 4, 12]
  bySetPos?: number;     // e.g. -1 (last), 1 (first), etc.
}

/**
 * For easy reference when you need label or mapping.
 * RRule's numeric day => 0=MO, 1=TU, etc.
 */
export const WEEKDAYS = [
  { value: 'MO', label: 'Monday' },
  { value: 'TU', label: 'Tuesday' },
  { value: 'WE', label: 'Wednesday' },
  { value: 'TH', label: 'Thursday' },
  { value: 'FR', label: 'Friday' },
  { value: 'SA', label: 'Saturday' },
  { value: 'SU', label: 'Sunday' },
];

// Map for reading RRule's day indexes.
const rruleToWeekdayMap: Record<number, string> = {
  0: 'MO',
  1: 'TU',
  2: 'WE',
  3: 'TH',
  4: 'FR',
  5: 'SA',
  6: 'SU',
};

// Map for writing to RRule's day indexes (the inverse).
const weekdayToRRuleMap: Record<string, number> = {
  MO: 0,
  TU: 1,
  WE: 2,
  TH: 3,
  FR: 4,
  SA: 5,
  SU: 6,
};

// Helpers for user-friendly text.
function getPositionText(pos: number): string {
  if (pos === -1) return 'last';
  const mapping = ['first', 'second', 'third', 'fourth'];
  return mapping[pos - 1] || `${pos}th`;
}

function getMonthName(month: number): string {
  // month is 1-based in RRule, so new Date(YYYY, month-1) is correct
  return new Date(2000, month - 1, 1).toLocaleString('default', { month: 'long' });
}

function getDayWithSuffix(day: number): string {
  const suffixes = ['th', 'st', 'nd', 'rd'];
  const v = day % 100;
  return day + (suffixes[(v - 20) % 10] || suffixes[v] || suffixes[0]);
}

/**
 * parseRRule()
 * Takes an existing RFC 5545 string (e.g. "FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=1")
 * and returns our friendly RuleConfig. If it fails, returns a default monthly config.
 */
export function parseRRule(rule?: string): RuleConfig {
  if (!rule) {
    // Default fallback: monthly on day 1.
    return { frequency: 'MONTHLY', interval: 1, byMonthDay: [1] };
  }

  try {
    const r = RRule.fromString(rule);
    const frequency: RuleConfig['frequency'] = ((): RuleConfig['frequency'] => {
      switch (r.options.freq) {
        case RRule.DAILY:   return 'DAILY';
        case RRule.WEEKLY:  return 'WEEKLY';
        case RRule.MONTHLY: return 'MONTHLY';
        case RRule.YEARLY:  return 'YEARLY';
        default:            return 'MONTHLY';
      }
    })();

    const config: RuleConfig = {
      frequency,
      interval: r.options.interval || 1,
    };

    // byMonth
    if (r.options.bymonth && r.options.bymonth.length > 0) {
      config.byMonth = r.options.bymonth;
    }

    // If we have bysetpos & byweekday, assume "pattern" mode (like "first Monday").
    if (typeof r.options.bysetpos !== 'undefined' && r.options.byweekday && r.options.byweekday.length) {
      config.bySetPos = r.options.bysetpos;
      config.byDay = r.options.byweekday.map((wd) => rruleToWeekdayMap[wd] || 'MO');
      return config;
    }

    // Otherwise, if we have bymonthday, that's "specific day(s)" mode.
    if (r.options.bymonthday && r.options.bymonthday.length) {
      config.byMonthDay = r.options.bymonthday;
    }

    // For weekly with multiple weekdays:
    if (r.options.byweekday && r.options.byweekday.length && typeof r.options.bysetpos === 'undefined') {
      config.byDay = r.options.byweekday.map((wd) => rruleToWeekdayMap[wd] || 'MO');
    }

    return config;
  } catch (err) {
    console.error('parseRRule error:', err);
    return { frequency: 'MONTHLY', interval: 1, byMonthDay: [1] };
  }
}

/**
 * generateRRule()
 * Takes our RuleConfig and returns a valid RFC 5545 string (e.g. "FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=1").
 */
export function generateRRule(config: RuleConfig): string {
  const options: Partial<RRuleOptions> = {};

  // Convert our frequency string to RRule freq.
  switch (config.frequency) {
    case 'DAILY':   options.freq = RRule.DAILY; break;
    case 'WEEKLY':  options.freq = RRule.WEEKLY; break;
    case 'MONTHLY': options.freq = RRule.MONTHLY; break;
    case 'YEARLY':  options.freq = RRule.YEARLY; break;
  }

  options.interval = config.interval || 1;

  // If we have a byMonth array and we're not just weekly, apply it.
  if (config.byMonth && config.byMonth.length && config.frequency !== 'WEEKLY') {
    options.bymonth = config.byMonth;
  }

  // byDay => byweekday
  if (config.byDay && config.byDay.length) {
    options.byweekday = config.byDay.map((day) => weekdayToRRuleMap[day.toUpperCase()]);
  }

  // byMonthDay
  if (config.byMonthDay && config.byMonthDay.length && config.frequency !== 'WEEKLY') {
    options.bymonthday = config.byMonthDay;
  }

  // bySetPos
  if (typeof config.bySetPos !== 'undefined' && config.frequency !== 'WEEKLY') {
    options.bysetpos = config.bySetPos;
  }

  const r = new RRule(options as RRuleOptions);
  return r.toString();
}

/**
 * getNextOccurrence()
 * Returns the very next occurrence date, or null if none exist.
 * If you want today's date included if it matches, set `inc=true`.
 */
export function getNextOccurrence(rule: string, fromDate: Date = new Date()): Date | null {
  if (!rule) return null;

  try {
    const r = RRule.fromString(rule);
    // Zero out the time if you only care about the date portion:
    const base = new Date(fromDate);
    base.setHours(0, 0, 0, 0);

    // 'true' means: if base date is itself an occurrence, return that date.
    const next = r.after(base, true);
    return next || null;
  } catch (err) {
    console.error('getNextOccurrence error:', err);
    return null;
  }
}

/**
 * getOccurrencesInRange()
 * The main function to answer: "Which dates in the rule fall between startDate and endDate (inclusive)?"
 * Returns an array of Date objects sorted from earliest to latest.
 */
export function getOccurrencesInRange(
  rule: string,
  startDate: Date,
  endDate: Date,
  originalStart?: Date | string,
): Date[] {
  if (!rule) return [];

  try {
    const r = RRule.fromString(rule);

    // If you want the recurrence to start specifically at 'originalStart', use dtstart for that.
    const dtstart = originalStart ? new Date(originalStart) : startDate;
    dtstart.setHours(0, 0, 0, 0);

    // Build a new RRule with the same info but ensure dtstart is what we want.
    const options: RRuleOptions = {
      ...r.options,
      dtstart,
    };

    const newRule = new RRule(options);
    // 'true' => inclusive of boundaries if they match.
    return newRule.between(startDate, endDate, true);
  } catch (err) {
    console.error('getOccurrencesInRange error:', err);
    return [];
  }
}

/**
 * getUiFriendlyText()
 * Returns a short-ish description like "Every week on Monday, Tuesday".
 */
export function getUiFriendlyText(rruleString: string): string {
  if (!rruleString) return '';

  try {
    const r = RRule.fromString(rruleString);
    const interval = r.options.interval || 1;
    const pieces: string[] = [];

    // Frequency
    switch (r.options.freq) {
      case RRule.DAILY:
        pieces.push(`Every ${interval > 1 ? `${interval} days` : 'day'}`);
        break;
      case RRule.WEEKLY:
        pieces.push(`Every ${interval > 1 ? `${interval} weeks` : 'week'}`);
        // If byweekday set, mention them:
        if (r.options.byweekday?.length) {
          const days = r.options.byweekday.map((wd) => {
            return WEEKDAYS.find((d) => d.value === rruleToWeekdayMap[wd])?.label || '';
          });
          pieces.push(`on ${days.join(', ')}`);
        }
        break;
      case RRule.MONTHLY:
        pieces.push(`Every ${interval > 1 ? `${interval} months` : 'month'}`);
        // If we have a bysetpos pattern, e.g. "first Monday":
        if (r.options.bysetpos && r.options.byweekday?.length) {
          const posText = getPositionText(r.options.bysetpos);
          const dayNum = r.options.byweekday[0];
          const dayLabel = WEEKDAYS.find((d) => d.value === rruleToWeekdayMap[dayNum])?.label;
          pieces.push(`on the ${posText} ${dayLabel}`);
        } else if (r.options.bymonthday?.length) {
          // If bymonthday is used, e.g. day 1, day 15
          pieces.push(`on day ${r.options.bymonthday.join(', ')}`);
        }
        break;
      case RRule.YEARLY:
        pieces.push(`Every ${interval > 1 ? `${interval} years` : 'year'}`);
        // If there's a pattern:
        if (r.options.bysetpos && r.options.byweekday?.length && r.options.bymonth?.length) {
          const posText = getPositionText(r.options.bysetpos);
          const dayNum = r.options.byweekday[0];
          const dayLabel = WEEKDAYS.find((d) => d.value === rruleToWeekdayMap[dayNum])?.label;
          const mName = getMonthName(r.options.bymonth[0]);
          pieces.push(`on the ${posText} ${dayLabel} in ${mName}`);
        } else if (r.options.bymonthday?.length && r.options.bymonth?.length) {
          const mName = getMonthName(r.options.bymonth[0]);
          const dayNum = r.options.bymonthday[0];
          pieces.push(`on ${mName} ${getDayWithSuffix(dayNum)}`);
        }
        break;
    }
    return pieces.join(' ');
  } catch (err) {
    console.error('getUiFriendlyText error:', err);
    return 'Invalid recurrence rule';
  }
}

/**
 * getDetailedDescription()
 * Similar to getUiFriendlyText() but you can embellish more detail if desired.
 */
export function getDetailedDescription(rruleString: string): string {
  if (!rruleString) return '';

  try {
    const r = RRule.fromString(rruleString);
    const pieces: string[] = [];
    const interval = r.options.interval || 1;

    switch (r.options.freq) {
      case RRule.DAILY:
        pieces.push(`Every ${interval > 1 ? `${interval} days` : 'day'}`);
        break;
      case RRule.WEEKLY:
        pieces.push(`Every ${interval > 1 ? `${interval} weeks` : 'week'}`);
        if (r.options.byweekday && r.options.byweekday.length) {
          const days = r.options.byweekday.map((wd) => {
            const label = WEEKDAYS.find((d) => d.value === rruleToWeekdayMap[wd])?.label;
            return label || 'UnknownDay';
          });
          pieces.push(`on ${days.join(', ')}`);
        }
        break;
      case RRule.MONTHLY:
        pieces.push(`Every ${interval > 1 ? `${interval} months` : 'month'}`);
        if (r.options.bysetpos && r.options.byweekday?.length) {
          const posText = getPositionText(r.options.bysetpos);
          const dayNum = r.options.byweekday[0];
          const dayLabel = WEEKDAYS.find((d) => d.value === rruleToWeekdayMap[dayNum])?.label;
          pieces.push(`on the ${posText} ${dayLabel}`);
        } else if (r.options.bymonthday?.length) {
          pieces.push(`on the ${r.options.bymonthday.map(getDayWithSuffix).join(', ')}`);
        }
        break;
      case RRule.YEARLY:
        pieces.push(`Every ${interval > 1 ? `${interval} years` : 'year'}`);
        if (r.options.bysetpos && r.options.byweekday?.length && r.options.bymonth?.length) {
          const posText = getPositionText(r.options.bysetpos);
          const dayNum = r.options.byweekday[0];
          const dayLabel = WEEKDAYS.find((d) => d.value === rruleToWeekdayMap[dayNum])?.label;
          const month = getMonthName(r.options.bymonth[0]);
          pieces.push(`on the ${posText} ${dayLabel} of ${month}`);
        } else if (r.options.bymonthday?.length && r.options.bymonth?.length) {
          const month = getMonthName(r.options.bymonth[0]);
          pieces.push(`on ${month} ${r.options.bymonthday.map(getDayWithSuffix).join(', ')}`);
        }
        break;
    }

    return pieces.join(' ');
  } catch (err) {
    console.error('getDetailedDescription error:', err);
    return 'Invalid recurrence rule';
  }
}

/**
 * getOccurrencesCountInRange()
 * Quickly returns the number of occurrences within a date range (inclusive).
 */
export function getOccurrencesCountInRange(
  rule: string,
  start: Date,
  end: Date,
  originalStart?: Date | string,
): number {
  const occurrences = getOccurrencesInRange(rule, start, end, originalStart);
  return occurrences.length;
}
