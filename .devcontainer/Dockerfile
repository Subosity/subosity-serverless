FROM docker:24.0.7-dind

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    git \
    nodejs \
    npm \
    postgresql-client \
    libc6-compat \
    sudo \
    shadow

# Install Supabase CLI
ENV SUPABASE_VERSION=2.26.9
RUN curl -L https://github.com/supabase/cli/releases/download/v${SUPABASE_VERSION}/supabase_linux_amd64.tar.gz \
  -o /tmp/supabase.tar.gz && \
  tar -xzf /tmp/supabase.tar.gz -C /tmp && \
  mv /tmp/supabase /usr/local/bin/supabase && \
  chmod +x /usr/local/bin/supabase && \
  rm /tmp/supabase.tar.gz

# Create non-root user and add to sudoers + docker group
RUN addgroup -g 1000 vscode && \
    adduser -u 1000 -G vscode -s /bin/bash -D vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    usermod -aG docker vscode

USER vscode
