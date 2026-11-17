CREATE DATABASE IF NOT EXISTS cineverse CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE cineverse;

CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  username VARCHAR(40) NOT NULL UNIQUE,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('user','admin') NOT NULL DEFAULT 'user',
  status ENUM('active','suspended') NOT NULL DEFAULT 'active',
  last_login_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE user_profiles (
  user_id BIGINT UNSIGNED PRIMARY KEY,
  photo_path VARCHAR(255) NULL,
  biography TEXT NULL,
  language VARCHAR(10) NOT NULL DEFAULT 'en',
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE genres (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(80) NOT NULL UNIQUE,
  description VARCHAR(255) NULL,
  image_path VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE actors (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(140) NOT NULL,
  biography TEXT NULL,
  photo_path VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_actors_name(name)
) ENGINE=InnoDB;
CREATE TABLE movies (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  synopsis TEXT NOT NULL,
  release_date DATE NOT NULL,
  runtime_minutes SMALLINT UNSIGNED NOT NULL,
  rating DECIMAL(3,1) NOT NULL DEFAULT 0 CHECK (rating BETWEEN 0 AND 10),
  language VARCHAR(60) NOT NULL DEFAULT 'English',
  poster_path VARCHAR(255) NULL,
  video_path VARCHAR(255) NULL,
  video_mime VARCHAR(80) NULL,
  trailer_url VARCHAR(500) NULL,
  availability ENUM('available','unavailable') NOT NULL DEFAULT 'available',
  publication_status ENUM('draft','published','archived') NOT NULL DEFAULT 'draft',
  popularity_score DECIMAL(10,2) NOT NULL DEFAULT 0,
  view_count BIGINT UNSIGNED NOT NULL DEFAULT 0,
  created_by BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE KEY uq_movie_title_release(title, release_date),
  INDEX idx_movies_release(release_date), INDEX idx_movies_popularity(popularity_score),
  INDEX idx_movies_status(publication_status,availability), FULLTEXT KEY ft_movies(title,synopsis)
) ENGINE=InnoDB;
CREATE TABLE movie_genres (
  movie_id BIGINT UNSIGNED NOT NULL,
  genre_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY(movie_id,genre_id),
  FOREIGN KEY(movie_id) REFERENCES movies(id) ON DELETE CASCADE,
  FOREIGN KEY(genre_id) REFERENCES genres(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE movie_cast (
  movie_id BIGINT UNSIGNED NOT NULL,
  actor_id BIGINT UNSIGNED NOT NULL,
  character_name VARCHAR(140) NOT NULL,
  display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY(movie_id,actor_id,character_name),
  FOREIGN KEY(movie_id) REFERENCES movies(id) ON DELETE CASCADE,
  FOREIGN KEY(actor_id) REFERENCES actors(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE movie_images (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  movie_id BIGINT UNSIGNED NOT NULL,
  image_path VARCHAR(255) NOT NULL,
  alt_text VARCHAR(180) NULL,
  display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(movie_id) REFERENCES movies(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE user_preferences (
  user_id BIGINT UNSIGNED NOT NULL,
  genre_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY(user_id,genre_id),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(genre_id) REFERENCES genres(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE watchlists (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE watchlist_items (
  watchlist_id BIGINT UNSIGNED NOT NULL,
  movie_id BIGINT UNSIGNED NOT NULL,
  added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY(watchlist_id,movie_id),
  FOREIGN KEY(watchlist_id) REFERENCES watchlists(id) ON DELETE CASCADE,
  FOREIGN KEY(movie_id) REFERENCES movies(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE viewing_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  movie_id BIGINT UNSIGNED NOT NULL,
  viewed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  duration_seconds INT UNSIGNED NOT NULL DEFAULT 0,
  INDEX idx_viewing_date(viewed_at), INDEX idx_viewing_movie(movie_id),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(movie_id) REFERENCES movies(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE recommendation_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  movie_id BIGINT UNSIGNED NOT NULL,
  reason VARCHAR(255) NOT NULL,
  generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_recommendation_date(generated_at),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(movie_id) REFERENCES movies(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE subscription_plans (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT NULL,
  price DECIMAL(10,2) NOT NULL CHECK(price>=0),
  currency CHAR(3) NOT NULL DEFAULT 'RWF',
  duration_months TINYINT UNSIGNED NOT NULL,
  duration_days SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  features JSON NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_plan_name_duration(name,duration_months,duration_days)
) ENGINE=InnoDB;
CREATE TABLE subscriptions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  plan_id BIGINT UNSIGNED NOT NULL,
  status ENUM('active','pending','expired','cancelled','suspended') NOT NULL DEFAULT 'pending',
  start_date DATE NOT NULL,
  expiry_date DATE NULL,
  renewal_date DATE NULL,
  cancelled_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_subscription_status(status), INDEX idx_subscription_renewal(renewal_date),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT,
  FOREIGN KEY(plan_id) REFERENCES subscription_plans(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE subscription_changes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  subscription_id BIGINT UNSIGNED NOT NULL,
  previous_plan_id BIGINT UNSIGNED NOT NULL,
  new_plan_id BIGINT UNSIGNED NOT NULL,
  effective_at DATETIME NOT NULL,
  adjustment_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  status ENUM('pending','applied','rejected') NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(subscription_id) REFERENCES subscriptions(id) ON DELETE RESTRICT,
  FOREIGN KEY(previous_plan_id) REFERENCES subscription_plans(id) ON DELETE RESTRICT,
  FOREIGN KEY(new_plan_id) REFERENCES subscription_plans(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE billing_records (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  subscription_id BIGINT UNSIGNED NOT NULL,
  subscription_change_id BIGINT UNSIGNED NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  amount DECIMAL(10,2) NOT NULL CHECK(amount>=0),
  transaction_reference VARCHAR(80) NOT NULL UNIQUE,
  payment_method VARCHAR(60) NULL,
  status ENUM('successful','pending','failed') NOT NULL DEFAULT 'pending',
  paid_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_billing_paid(paid_at), INDEX idx_billing_status(status),
  FOREIGN KEY(subscription_id) REFERENCES subscriptions(id) ON DELETE RESTRICT,
  FOREIGN KEY(subscription_change_id) REFERENCES subscription_changes(id) ON DELETE RESTRICT,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE audit_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  actor_user_id BIGINT UNSIGNED NULL,
  action VARCHAR(80) NOT NULL,
  entity_type VARCHAR(60) NOT NULL,
  entity_id BIGINT UNSIGNED NULL,
  details JSON NULL,
  ip_address VARCHAR(45) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_entity(entity_type,entity_id), INDEX idx_audit_created(created_at),
  FOREIGN KEY(actor_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

INSERT INTO genres(name) VALUES ('Action'),('Adventure'),('Comedy'),('Drama'),('Horror'),('Romance'),('Science Fiction'),('Thriller'),('Animation'),('Documentary');
INSERT INTO subscription_plans(name,description,price,currency,duration_months,duration_days,features) VALUES
 ('Free','Start watching Cineverse movies at no cost.',0,'RWF',0,0,'["Watch published movies","Download movies","Standard quality"]'),
 ('Weekly','Seven days of Cineverse access.',1000,'RWF',0,7,'["Watch published movies","Download movies","Standard quality"]'),
 ('Monthly','One month of Cineverse access.',3000,'RWF',1,0,'["Watch published movies","Download movies","HD quality"]');
