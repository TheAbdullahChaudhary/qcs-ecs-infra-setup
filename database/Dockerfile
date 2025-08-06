FROM postgres:15-alpine

# Set environment variables
ENV POSTGRES_DB=ecsdb
ENV POSTGRES_USER=ecsuser
ENV POSTGRES_PASSWORD=ecspassword

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/

# Copy custom PostgreSQL configuration
COPY postgresql.conf /etc/postgresql/postgresql.conf

# Create data directory with proper permissions
RUN mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql/data && \
    chmod 700 /var/lib/postgresql/data

# Expose PostgreSQL port
EXPOSE 5432

# Use custom configuration
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"] 