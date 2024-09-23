# Personalized Snake Game

This Bash script is a personalized terminal-based Snake game with custom colors, interactive gameplay, and real-time updates. The game adjusts the size of the game board according to your terminal dimensions and provides a unique gaming experience.

## How to Play

1. **Run the Game:**

   - Ensure you have Bash installed on your system.
   - Save the script in a file (e.g., `snake.sh`).
   - Make the script executable:
     ```bash
     chmod +x snake.sh
     ```
   - Start the game:
     ```bash
     ./snake.sh
     ```

2. **Controls:**

   - Use the arrow keys or `W`, `A`, `S`, `D` to move the snake:
     - `W` or Up Arrow: Move Up
     - `A` or Left Arrow: Move Left
     - `S` or Down Arrow: Move Down
     - `D` or Right Arrow: Move Right
   - Press `Q` to quit the game.

3. **Objective:**
   - Guide the snake to eat the food (`★`) that appears on the board. Each piece of food increases the snake's length and score.
   - Avoid running into the walls or your own tail; doing so will end the game.

## Features

- **Dynamic Board Size:** Adjusts automatically to your terminal size.
- **Personalized Experience:** Welcomes the player by their username.
- **Color-Coded Gameplay:**
  - Yellow border
  - Green snake
  - Red food
- **Score Display:** Your current score is displayed during the game.

## Exit the Game

- To exit the game safely, press `Q`. The game will restore your terminal settings.

## Terminal Settings

The game hides the cursor and disables echoing of typed characters during gameplay to provide a clean experience. These settings are restored when you exit the game.

---

Enjoy the game and challenge yourself to achieve the highest score!
