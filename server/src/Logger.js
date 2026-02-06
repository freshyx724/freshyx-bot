class Logger {
  constructor() {
    this.logs = [];
    this.maxLogs = 1000;
  }

  log(level, message, data = null) {
    const entry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      data
    };
    
    this.logs.push(entry);
    
    if (this.logs.length > this.maxLogs) {
      this.logs.shift();
    }
    
    const formatted = `[${level.toUpperCase()}] ${message}${data ? ' ' + JSON.stringify(data) : ''}`;
    console.log(formatted);
    
    return entry;
  }

  info(message, data) {
    return this.log('info', message, data);
  }

  error(message, data) {
    return this.log('error', message, data);
  }

  warn(message, data) {
    return this.log('warn', message, data);
  }

  debug(message, data) {
    return this.log('debug', message, data);
  }

  getRecentLogs(count = 100) {
    return this.logs.slice(-count);
  }

  clear() {
    this.logs = [];
  }
}

module.exports = new Logger();
