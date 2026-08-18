/*
File: uart_echo.c
Purpose
This firmware demonstrates basic UART communication using memory-mapped I/O.
It is typically used in a simple RISC-V SoC or embedded system where the CPU
communicates with peripherals through fixed memory addresses.

The program performs two main tasks:
1. Prints a greeting message multiple times over UART.
2. Enters an infinite loop that echoes back any character received via UART.

Concept: Memory-Mapped I/O
--------------------------
In many embedded systems and SoCs, hardware peripherals (UART, SPI, GPIO, etc.)
are accessed through specific memory addresses. Reading or writing to these
addresses directly controls the hardware.

Example:
Writing to UART_TX register sends a character over the serial interface.
Reading from UART_RX register retrieves a received character.
*/
/*
------------------------------------------------------------------------------
 UART Register Mapping
------------------------------------------------------------------------------
These macros map UART hardware registers to specific memory addresses.

The 'volatile' keyword is critical here. It tells the compiler that the value
at this memory location may change due to hardware activity, so it must not
optimize away reads or writes.

Without 'volatile', the compiler might cache values in registers and break
hardware communication.
*/

/* UART transmit register
   Writing a byte to this address sends it through the UART transmitter */
#define UART_TX      (*(volatile char*)0x10000000)

/* UART receive register
   Reading from this address retrieves the received byte from UART */
#define UART_RX      (*(volatile char*)0x10000004)

/* UART status register
   Used to check if data is available or if the transmitter is ready */
#define UART_STATUS  (*(volatile int*)0x10000008)
/*
------------------------------------------------------------------------------
 Function: uart_putc
------------------------------------------------------------------------------
Purpose:
    Send a single character over UART.

Parameter:
    c : character to transmit

Operation:
    Writing the character to the UART transmit register triggers the
    hardware UART module to send the byte serially.

Note:
    This implementation assumes the transmitter is always ready.
    More advanced UART drivers would check a TX-ready status bit first.
*/
static void uart_putc(char c)
{
    UART_TX = c;   // Write character to UART transmit register
}

/*
------------------------------------------------------------------------------
 Function: uart_puts
------------------------------------------------------------------------------
Purpose:
    Send a null-terminated string over UART.

Parameter:
    s : pointer to a string

Operation:
    The function loops through each character of the string until the
    null terminator ('\0') is reached, sending each character using
    uart_putc().

Example:
    uart_puts("Hello\n");

This is a common pattern in embedded firmware for printing debug messages.
*/
static void uart_puts(const char *s)
{
    while (*s)          // Continue until end of string ('\0')
        uart_putc(*s++); // Send current character and move to next
}


/*
------------------------------------------------------------------------------
 Function: uart_getc
------------------------------------------------------------------------------
Purpose:
    Receive one character from UART.

Operation:
    This function performs a blocking read. It continuously checks the
    UART status register until a character is available.

UART_STATUS & 0x2:
    Bit 1 is assumed to indicate that receive data is available.

Process:
    1. Poll the UART_STATUS register.
    2. Wait until RX-ready bit becomes set.
    3. Read the received character from UART_RX register.

Blocking behavior:
    The CPU will remain in the loop until a character arrives.
*/
static char uart_getc(void)
{
    /* Wait until RX data available bit is set */
    while (!(UART_STATUS & 0x2))
        ;

    /* Read and return the received character */
    return UART_RX;
}


/*
------------------------------------------------------------------------------
 Function: main
------------------------------------------------------------------------------
Entry point of the firmware.

Program Flow:
1. Send a greeting message multiple times over UART.
2. Enter an infinite loop where the program echoes received characters.

This is commonly used as a basic UART test program in FPGA/SoC bring-up.
*/
int main(void)
{
    char c;  // Variable to store received character
    int i;   // Loop counter


    /*
    --------------------------------------------------------------------------
    Print greeting message
    --------------------------------------------------------------------------
    This loop sends the greeting string 10 times over UART.
    Useful for verifying that the UART transmitter and terminal are working.
    */
    for (i = 0; i < 10; i++)
    {
        uart_puts("Hello Deepak from Nielit!\n");
    }


    /*
    --------------------------------------------------------------------------
    UART Echo Loop
    --------------------------------------------------------------------------
    This infinite loop continuously receives characters from UART
    and sends them back.

    Behavior:
        If a user types in a serial terminal, the same character
        will be immediately transmitted back (echoed).

    This is commonly used to verify UART RX and TX functionality.
    */
    while (1)
    {
        /* Wait for a character from UART */
        c = uart_getc();

        /* Send the same character back */
        uart_putc(c);
    }

    /*
    This line is never reached because the program runs indefinitely.
    It is included for completeness and standard C convention.
    */
    return 0;
}
