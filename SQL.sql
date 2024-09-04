SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

CREATE TABLE `ax_garages` (
  `id` int(11) NOT NULL,
  `coords` text DEFAULT NULL,
  `name` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

ALTER TABLE `ax_garages`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `ax_garages`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

ALTER TABLE 'vrp_user_vehicles'
    ADD COLUMN `vehicle` varchar(100) DEFAULT NULL;

ALTER TABLE 'vrp_user_vehicles'
    ADD COLUMN `veh_name` varchar(100) DEFAULT NULL;

ALTER TABLE 'vrp_user_vehicles'
    ADD COLUMN `veh_plate` varchar(255) DEFAULT NULL;

ALTER TABLE 'vrp_user_vehicles'
    ADD COLUMN `fuel` text DEFAULT NULL;

ALTER TABLE 'vrp_user_vehicles'
    ADD COLUMN `engine` text DEFAULT NULL;

ALTER TABLE 'vrp_user_vehicles'
    ADD COLUMN `status` text DEFAULT NULL;

ALTER TABLE 'vrp_user_vehicles'
    ADD COLUMN `garage` text DEFAULT NULL;

ALTER TABLE 'vrp_user_vehicles'
    ADD COLUMN `veh_damage` LONGTEXT DEFAULT NULL;
COMMIT;