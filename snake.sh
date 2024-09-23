
# Disable word splitting to preserve whitespace in arrays
IFS=''

# Get the current username
username=$(whoami)

# Calculate the game board dimensions based on the terminal size
declare -i height=$(($(tput lines)-5))  # Height of the game board
declare -i width=$(($(tput cols)-2))    # Width of the game board

# Initialize the snake's head and tail positions
declare -i head_r head_c tail_r tail_c

# Game state variables
declare -i alive          # Alive flag (0=alive, 1=dead)
declare -i length         # Length of the snake
declare body              # String representing the snake's body directions

# Direction and score variables
declare -i direction      # Current direction of the snake
declare -i delta_dir      # Change in direction
declare -i score=0        # Player's score

# Color definitions for the game elements
border_color="\e[33;40m"   # Yellow on black for the border
snake_color="\e[32;40m"    # Green on black for the snake
food_color="\e[31;40m"     # Red on black for the food
text_color="\e[37;40m"     # White on black for text
no_color="\e[0m"           # Reset color

# Characters used for the snake and food
snake_char='█'
food_char='★'

# Signal definitions for inter-process communication
SIG_UP=USR1
SIG_RIGHT=USR2
SIG_DOWN=URG
SIG_LEFT=IO
SIG_QUIT=WINCH
SIG_DEAD=HUP

# Direction arrays: index represents the direction (0=up, 1=right, 2=down, 3=left)
# Each element represents the change in row (move_r) or column (move_c) for that direction
move_r=([0]=-1 [1]=0 [2]=1 [3]=0)   # Row movement
move_c=([0]=0 [1]=1 [2]=0 [3]=-1)   # Column movement

# Function to initialize the game
init_game() {
    clear
    echo -ne "\e[?25l"  # Hide the cursor
    stty -echo          # Disable echoing of typed characters

    # Display a welcome message
    echo -e "${text_color}Welcome to the Personalized Snake Game!${no_color}"
    echo -e "${text_color}Hello, $username! Get ready to play!${no_color}"
    sleep 2
    clear

    # Initialize the game board array with empty spaces
    for ((i=0; i<height; i++)); do
        for ((j=0; j<width; j++)); do
            eval "arr$i[$j]=' '"
        done
    done
}

# Function to move the cursor to a specific position and draw a character
move_and_draw() {
    # Arguments:
    #   $1 - Row position
    #   $2 - Column position
    #   $3 - Character to draw
    echo -ne "\e[${1};${2}H$3"
}

# Function to draw the entire game board
draw_board() {
    # Draw the top border
    move_and_draw 1 1 "$border_color+$no_color"
    for ((i=2; i<=width+1; i++)); do
        move_and_draw 1 $i "$border_color-$no_color"
    done
    move_and_draw 1 $((width + 2)) "$border_color+$no_color"
    echo

    # Draw the game area with the snake and food
    for ((i=0; i<height; i++)); do
        # Draw the left border
        move_and_draw $((i+2)) 1 "$border_color|$no_color"
        # Draw the content of the row
        eval echo -en "\"\${arr$i[*]}\""
        # Draw the right border
        echo -e "$border_color|$no_color"
    done

    # Draw the bottom border
    move_and_draw $((height+2)) 1 "$border_color+$no_color"
    for ((i=2; i<=width+1; i++)); do
        move_and_draw $((height+2)) $i "$border_color-$no_color"
    done
    move_and_draw $((height+2)) $((width + 2)) "$border_color+$no_color"
    echo
}

# Function to initialize the snake's starting position and body
init_snake() {
    alive=0            # Set the snake as alive
    length=10          # Initial length of the snake
    direction=0        # Initial direction (0=up)
    delta_dir=-1       # No direction change initially

    # Set the initial position of the snake's head to the center of the game board
    head_r=$((height/2-2))
    head_c=$((width/2))

    body=''            # Initialize the body directions string
    # Build the initial body directions (moving right)
    for ((i=0; i<length-1; i++)); do
        body="1$body"
    done

    # Calculate the initial position of the tail
    local p=$((${move_r[1]} * (length-1)))  # Total row offset
    local q=$((${move_c[1]} * (length-1)))  # Total column offset
    tail_r=$((head_r+p))
    tail_c=$((head_c+q))

    # Place the head on the game board
    eval "arr$head_r[$head_c]=\"${snake_color}${snake_char}$no_color\""

    # Build the initial body on the game board
    prev_r=$head_r
    prev_c=$head_c
    b=$body
    while [ -n "$b" ]; do
        # Get the direction from the body string
        local dir=$(echo $b | grep -o '^[0-3]')
        local p=${move_r[$dir]}   # Row movement for this segment
        local q=${move_c[$dir]}   # Column movement for this segment

        # Calculate the new position
        new_r=$((prev_r+p))
        new_c=$((prev_c+q))

        # Place the body segment on the game board
        eval "arr$new_r[$new_c]=\"${snake_color}${snake_char}$no_color\""

        # Update the previous position
        prev_r=$new_r
        prev_c=$new_c

        # Remove the processed direction from the body string
        b=${b#[0-3]}
    done
}

# Function to check if the snake has collided (with walls or itself)
is_dead() {
    # Arguments:
    #   $1 - Row position to check
    #   $2 - Column position to check

    # Check if the position is outside the game board boundaries
    if [ "$1" -lt 0 ] || [ "$1" -ge "$height" ] || \
       [ "$2" -lt 0 ] || [ "$2" -ge "$width" ]; then
        return 0  # Dead
    fi

    # Check if the position is occupied by the snake's body
    eval "local pos=\${arr$1[$2]}"
    if [ "$pos" == "${snake_color}${snake_char}$no_color" ]; then
        return 0  # Dead
    fi

    return 1  # Alive
}

# Function to place food randomly on the game board
give_food() {
    local food_r food_c
    local pos

    # Find a random empty position to place the food
    while true; do
        food_r=$((RANDOM % height))
        food_c=$((RANDOM % width))
        eval "pos=\${arr$food_r[$food_c]}"
        if [ "$pos" == ' ' ]; then
            break
        fi
    done

    # Place the food on the game board
    eval "arr$food_r[$food_c]=\"$food_color${food_char}$no_color\""
}

# Function to move the snake based on the current direction
move_snake() {
    # Calculate the new head position
    local newhead_r=$((head_r + move_r[direction]))
    local newhead_c=$((head_c + move_c[direction]))

    # Get the content at the new position
    eval "local pos=\${arr$newhead_r[$newhead_c]}"

    # Check for collision
    if $(is_dead $newhead_r $newhead_c); then
        alive=1  # Snake is dead
        return
    fi

    # Check if the snake has found food
    if [ "$pos" == "$food_color${food_char}$no_color" ]; then
        length+=1  # Increase the length of the snake
        score+=1   # Increase the player's score

        # Place the new head on the game board
        eval "arr$newhead_r[$newhead_c]=\"${snake_color}${snake_char}$no_color\""

        # Update the body directions
        body="$(((direction+2)%4))$body"
        head_r=$newhead_r
        head_c=$newhead_c

        # Place new food on the game board
        give_food
        return
    fi

    # Move the snake forward
    head_r=$newhead_r
    head_c=$newhead_c

    # Update the body directions
    local d=$(echo $body | grep -o '[0-3]$')  # Direction of the tail
    body="$(((direction+2)%4))${body%[0-3]}"

    # Remove the tail from the game board
    eval "arr$tail_r[$tail_c]=' '"

    # Place the new head on the game board
    eval "arr$head_r[$head_c]=\"${snake_color}${snake_char}$no_color\""

    # Update the tail position
    local p=${move_r[(d+2)%4]}
    local q=${move_c[(d+2)%4]}
    tail_r=$((tail_r+p))
    tail_c=$((tail_c+q))
}

# Function to change the direction of the snake
change_dir() {
    # Argument:
    #   $1 - New direction to change to
    # Prevent the snake from reversing direction
    if [ $(((direction+2)%4)) -ne $1 ]; then
        direction=$1
    fi
    delta_dir=-1  # Reset the delta direction
}

# Function to handle user input for controlling the snake
getchar() {
    # Ignore interrupt and quit signals
    trap "" SIGINT SIGQUIT
    # Handle the signal when the snake is dead
    trap "return;" $SIG_DEAD

    while true; do
        read -rsn1 key  # Read one character silently

        # Handle arrow keys (which are multi-character sequences)
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 key2
            key+=$key2
        fi

        case "$key" in
            [qQ])  # Quit the game
                kill -$SIG_QUIT $game_pid
                echo -e "${text_color}Goodbye, $username! Thanks for playing.$no_color"
                return
                ;;
            [wW]|$'\e[A')  # Move up
                kill -$SIG_UP $game_pid
                ;;
            [dD]|$'\e[C')  # Move right
                kill -$SIG_RIGHT $game_pid
                ;;
            [sS]|$'\e[B')  # Move down
                kill -$SIG_DOWN $game_pid
                ;;
            [aA]|$'\e[D')  # Move left
                kill -$SIG_LEFT $game_pid
                ;;
        esac
    done
}

# Main game loop function
game_loop() {
    # Set up traps for direction change signals
    trap "delta_dir=0;" $SIG_UP      # Up
    trap "delta_dir=1;" $SIG_RIGHT   # Right
    trap "delta_dir=2;" $SIG_DOWN    # Down
    trap "delta_dir=3;" $SIG_LEFT    # Left
    trap "exit 1;" $SIG_QUIT         # Quit the game

    while [ "$alive" -eq 0 ]; do
        # Display the current score
        echo -e "\n${text_color}           Your score: $score $no_color"

        # Change direction if a new direction is set
        if [ "$delta_dir" -ne -1 ]; then
            change_dir $delta_dir
        fi

        # Move the snake and redraw the game board
        move_snake
        draw_board

        # Control the game speed
        sleep 0.03
    done

    # Game over message
    echo -e "${text_color}Game Over, $username! Your final score: $score$no_color"

    # Signal the input loop that the snake is dead
    kill -$SIG_DEAD $$
}

# Function to reset terminal settings when the game exits
clear_game() {
    stty echo           # Enable echoing of typed characters
    echo -e "\e[?25h"   # Show the cursor
}

# Initialize and start the game
init_game          # Set up the game environment
init_snake         # Initialize the snake's position
give_food          # Place the first food item
draw_board         # Draw the initial game board

# Start the game loop in the background
game_loop &
game_pid=$!

# Start capturing user input
getchar

# Clean up and exit the game
clear_game
exit 0