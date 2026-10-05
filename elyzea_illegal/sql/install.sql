-- =========================================================
--  ELYZEA ILLÉGAL - BASE DE DONNÉES
--  Les tables sont aussi créées automatiquement au démarrage de la
--  ressource : ce fichier n'est utile que pour une installation manuelle.
--
--  illegal_groups ─┬─ illegal_grades ── illegal_members
--                  ├─ illegal_finances ── illegal_transactions
--                  ├─ illegal_peds
--                  ├─ illegal_stashes
--                  ├─ illegal_orders ── illegal_order_requests (livraison : ready_at, spot)
--                  └─ illegal_logs
--  Supprimer un groupe supprime tout le reste (ON DELETE CASCADE).
-- =========================================================

CREATE TABLE IF NOT EXISTS `illegal_groups` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name`        VARCHAR(32)  NOT NULL,
    `label`       VARCHAR(64)  NOT NULL,
    `type`        VARCHAR(20)  NOT NULL DEFAULT 'gang',
    `description` VARCHAR(500) NOT NULL DEFAULT '',
    `color`       VARCHAR(7)   NOT NULL DEFAULT '#e0433b',
    `settings`    LONGTEXT     NULL,
    `created_by`  VARCHAR(64)  NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_illegal_groups_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `illegal_grades` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `group_id`    INT UNSIGNED NOT NULL,
    `name`        VARCHAR(32)  NOT NULL,
    `label`       VARCHAR(64)  NOT NULL,
    `level`       INT          NOT NULL DEFAULT 0,
    `is_boss`     TINYINT(1)   NOT NULL DEFAULT 0,
    `permissions` LONGTEXT     NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_illegal_grades_name` (`group_id`, `name`),
    CONSTRAINT `fk_illegal_grades_group` FOREIGN KEY (`group_id`) REFERENCES `illegal_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Un personnage (citizenid) n'appartient qu'à un seul groupe illégal
CREATE TABLE IF NOT EXISTS `illegal_members` (
    `citizenid`   VARCHAR(50)  NOT NULL,
    `group_id`    INT UNSIGNED NOT NULL,
    `grade_id`    INT UNSIGNED NOT NULL,
    `name`        VARCHAR(100) NOT NULL DEFAULT '',
    `joined_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen`   TIMESTAMP    NULL DEFAULT NULL,
    PRIMARY KEY (`citizenid`),
    KEY `idx_illegal_members_group` (`group_id`),
    CONSTRAINT `fk_illegal_members_group` FOREIGN KEY (`group_id`) REFERENCES `illegal_groups` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_illegal_members_grade` FOREIGN KEY (`grade_id`) REFERENCES `illegal_grades` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Deux comptes strictement séparés
CREATE TABLE IF NOT EXISTS `illegal_finances` (
    `group_id`    INT UNSIGNED    NOT NULL,
    `clean`       BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `dirty`       BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at`  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`group_id`),
    CONSTRAINT `fk_illegal_finances_group` FOREIGN KEY (`group_id`) REFERENCES `illegal_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `illegal_transactions` (
    `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `group_id`       INT UNSIGNED NOT NULL,
    `account`        VARCHAR(8)   NOT NULL,
    `type`           VARCHAR(20)  NOT NULL,
    `amount`         BIGINT       NOT NULL,
    `balance_before` BIGINT       NOT NULL,
    `balance_after`  BIGINT       NOT NULL,
    `actor`          VARCHAR(100) NOT NULL DEFAULT '',
    `actor_cid`      VARCHAR(50)  NULL,
    `reason`         VARCHAR(200) NOT NULL DEFAULT '',
    `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_illegal_tx_group` (`group_id`, `id`),
    CONSTRAINT `fk_illegal_tx_group` FOREIGN KEY (`group_id`) REFERENCES `illegal_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `illegal_peds` (
    `group_id`    INT UNSIGNED NOT NULL,
    `model`       VARCHAR(64)  NOT NULL,
    `x`           DOUBLE       NOT NULL,
    `y`           DOUBLE       NOT NULL,
    `z`           DOUBLE       NOT NULL,
    `heading`     DOUBLE       NOT NULL DEFAULT 0,
    `scenario`    VARCHAR(64)  NOT NULL DEFAULT '',
    `menu`        LONGTEXT     NULL,
    PRIMARY KEY (`group_id`),
    CONSTRAINT `fk_illegal_peds_group` FOREIGN KEY (`group_id`) REFERENCES `illegal_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catalogue : group_id NULL = commande proposée à tous les groupes (créée par le staff)
CREATE TABLE IF NOT EXISTS `illegal_orders` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `group_id`    INT UNSIGNED NULL,
    `name`        VARCHAR(64)  NOT NULL,
    `description` VARCHAR(500) NOT NULL DEFAULT '',
    `category`    VARCHAR(20)  NOT NULL DEFAULT 'other',
    `price`       BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `payment`     VARCHAR(8)   NOT NULL DEFAULT 'dirty',
    `available`   TINYINT(1)   NOT NULL DEFAULT 1,
    `item`        VARCHAR(64)  NULL,
    `item_count`  INT UNSIGNED NOT NULL DEFAULT 1,
    `created_by`  VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_illegal_orders_group` (`group_id`),
    CONSTRAINT `fk_illegal_orders_group` FOREIGN KEY (`group_id`) REFERENCES `illegal_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `illegal_order_requests` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `group_id`     INT UNSIGNED NOT NULL,
    `order_id`     INT UNSIGNED NULL,
    `order_name`   VARCHAR(64)  NOT NULL,
    `quantity`     INT UNSIGNED NOT NULL DEFAULT 1,
    `total`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `account`      VARCHAR(8)   NOT NULL,
    `item`         VARCHAR(64)  NULL,
    `item_count`   INT UNSIGNED NOT NULL DEFAULT 0,
    `status`       VARCHAR(12)  NOT NULL DEFAULT 'pending',
    `requester`    VARCHAR(100) NOT NULL DEFAULT '',
    `requester_cid` VARCHAR(50) NOT NULL,
    `handled_by`   VARCHAR(100) NULL,
    `ready_at`     INT UNSIGNED NULL,
    `spot`         LONGTEXT     NULL,
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   TIMESTAMP    NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_illegal_requests_group` (`group_id`, `status`),
    CONSTRAINT `fk_illegal_requests_group` FOREIGN KEY (`group_id`) REFERENCES `illegal_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Coffre du groupe (inventaire ox_inventory « illegal_stash_<id> »)
CREATE TABLE IF NOT EXISTS `illegal_stashes` (
    `group_id`    INT UNSIGNED NOT NULL,
    `label`       VARCHAR(64)  NOT NULL DEFAULT 'Coffre',
    `model`       VARCHAR(64)  NOT NULL,
    `x`           DOUBLE       NOT NULL,
    `y`           DOUBLE       NOT NULL,
    `z`           DOUBLE       NOT NULL,
    `heading`     DOUBLE       NOT NULL DEFAULT 0,
    `weight`      INT UNSIGNED NOT NULL DEFAULT 500,
    `slots`       INT UNSIGNED NOT NULL DEFAULT 50,
    PRIMARY KEY (`group_id`),
    CONSTRAINT `fk_illegal_stashes_group` FOREIGN KEY (`group_id`) REFERENCES `illegal_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Lieux de livraison des commandes (placés par le staff)
CREATE TABLE IF NOT EXISTS `illegal_delivery_spots` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `label`       VARCHAR(64)  NOT NULL DEFAULT '',
    `x`           DOUBLE       NOT NULL,
    `y`           DOUBLE       NOT NULL,
    `z`           DOUBLE       NOT NULL,
    `heading`     DOUBLE       NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Journal : group_id NULL = action générale (ex. suppression d'un groupe)
CREATE TABLE IF NOT EXISTS `illegal_logs` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `group_id`    INT UNSIGNED NULL,
    `actor`       VARCHAR(100) NOT NULL DEFAULT '',
    `action`      VARCHAR(64)  NOT NULL,
    `details`     VARCHAR(500) NOT NULL DEFAULT '',
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_illegal_logs_group` (`group_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
