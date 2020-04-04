# Pairing generator

Generate pairings for the Witch vs Spitir Keyforge tournament

## Usage

You'll need ruby installed on your computed to use the script. Then, grant executable permissions to the script using:

```
chmod +x tournament.rb
```

Finally you can run `./tournament.rb --help` to have a list of the available commands.

## Command examples

```
> ./tournament.rb --initialize-pool witch 7,32,13,99,121,203
> ./tournament.rb --initialize-pool spirit 12,29,73,46,19,26
> ./tournament.rb --pairing
> ./tournament.rb --print-pairing
> ./tournament.rb --set-results 73w,99w
> ./tournament.rb --print-results
```
