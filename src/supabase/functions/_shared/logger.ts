//import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";

export class Logger {
  constructor(private context: string) {}

  info(message: string, data?: any) {
    console.log(JSON.stringify({
      level: 'INFO',
      context: this.context,
      message,
      data,
      timestamp: new Date().toISOString()
    }));
  }

  error(message: string, error: Error, data?: any) {
    console.error(JSON.stringify({
      level: 'ERROR',
      context: this.context,
      message,
      error: {
        message: error.message,
        stack: error.stack
      },
      data,
      timestamp: new Date().toISOString()
    }));
  }
}