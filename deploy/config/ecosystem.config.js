module.exports = {
  apps: [
    {
      name: 'im-bot-gateway',
      script: 'src/index.js',
      
      cwd: '/opt/im-bot-gateway/server',
      
      instances: 1,
      exec_mode: 'fork',
      
      autorestart: true,
      watch: false,
      
      max_memory_restart: '500M',
      max_restarts: 10,
      min_uptime: '10s',
      
      restart_delay: 1000,
      
      env: {
        NODE_ENV: 'production',
        PORT: 8767,
        LOG_LEVEL: 'info'
      },
      
      env_development: {
        NODE_ENV: 'development',
        PORT: 8767,
        LOG_LEVEL: 'debug'
      },
      
      env_test: {
        NODE_ENV: 'test',
        PORT: 8767,
        LOG_LEVEL: 'debug'
      },
      
      // 日志配置
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      log_file: '/var/log/im-bot-gateway/combined.log',
      error_file: '/var/log/im-bot-gateway/error.log',
      out_file: '/var/log/im-bot-gateway/out.log',
      
      // 压缩日志
      merge_logs: true,
      
      // 进程ID文件
      pid_file: '/var/run/im-bot-gateway.pid',
      
      // 监听配置
      listen_timeout: 3000,
      kill_timeout: 5000,
      
      // 自动退出（无活动时）
      // pm2-runtime 会保持运行
      
      // 资源监控
      node_args: '--max-old-space-size=256'
    }
  ],
  
  // 部署配置
  deploy: {
    production: {
      user: 'deploy',
      host: ['0.0.0.0'],
      ref: 'origin/master',
      repo: 'git@github.com:your-repo/im-bot-gateway.git',
      path: '/opt/im-bot-gateway',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js'
    }
  }
};
