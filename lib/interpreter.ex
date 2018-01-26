defmodule ElixirLispInterpreter.Interpreter do
  use GenServer

  ## CLIENT API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def run_file(pid, file_path) do
    GenServer.call(pid, {:run, file_path})
  end

  ## SERVER CALLBACKS

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:run, file_path}, _from, cache) do
    {:ok, results} = file_path |> File.read |> parse_lisp  
    {:reply, results, cache}
  end

  ## HELPER FUNCTIONS

  defp standard_environment do
    %{
      :+ => &(&1 + &2) ,
      :- => &(&1 - &2) ,
      :* => &(&1 * &2) ,
      :/ => &(&1 / &2) ,
      :> => &(&1 > &2) ,
      :>= => &(&1 >= &2) ,
      :< => &(&1 < &2) ,
      :<= => &(&1 <= &2) ,
      := => &(&1 = &2) ,
      :pi => :math.pi(),
      :abs => fn val -> abs(val) end ,
      :append => &(&1 + &2) ,
      :apply => fn proc, args -> apply(proc, args) end ,
      :car => fn [head | _] -> head end,
      :cdr => fn [_ | tail] -> tail end,
      :cons => fn x, y -> [x] ++ y end,
      :eq? => &(&1 === &2),
      :expt => fn x, y -> :math.pow(x, y) end,
      :equal? => &(&1 == &2),
      :length => fn x -> length(x) end,
      :list? => fn x -> is_list(x) end,
    }
  end

  defp parse_lisp({:ok, file}) do
    result = file |> tokenize |> read_from_tokens |> eval_compiled(standard_environment)
    {:ok, result}
  end

  defp tokenize(chars) do
    chars 
    |> String.replace("(", "( ") 
    |> String.replace(")", " )")
    |> String.split(" ")
  end

  defp read_from_tokens(tokens), do: read_from_tokens(tokens, [])
  defp read_from_tokens(tokens, list) when length(tokens) == 0, do: "err"
  defp read_from_tokens(tokens, list) when tokens === [")"], do: {:done, list |> Enum.reverse }
  defp read_from_tokens([head | tail], list) when head == ")", do: {:ok, tail, list |> Enum.reverse }
  defp read_from_tokens([head | tail], list) when head == "(" do
    case read_from_tokens(tail, []) do
      {:ok, new_tail, current_scope} -> 
        read_from_tokens(new_tail, [current_scope | list])
      {:done, list} -> 
        list
    end
  end
  defp read_from_tokens([head | tail], list) do
    try do
      value = head |> String.to_integer
      read_from_tokens(tail, [value | list]) 
    rescue
      _ -> 
        value = head |> String.to_atom
        read_from_tokens(tail, [value | list])
    end
  end 

  defp eval_compiled(atom, env) when is_atom(atom), do: env[atom]
  defp eval_compiled(number, env) when is_number(number), do: number
  defp eval_compiled([head | tail], env) when head === :if do
    [condition, consequence, alt] = tail
    expression = if eval_compiled(condition, env), do: consequence, else: alt
    eval_compiled(expression, env)
  end
  defp eval_compiled([head | tail], env) when head === :define do
    [symbol, expression] = tail
    var = eval_compiled(expression, env)
    ## ENV IS NOT GETTING UPDATED FOR NEXT CALL  
    Map.put(env, symbol, var)
    var
  end
  defp eval_compiled([head | tail], env) when head === :list do
    Enum.map(tail, fn(elem) -> eval_compiled(elem, env) end)
  end
  defp eval_compiled([head | tail], env) when head === :begin do
    eval_compiled(List.last(tail), env)
  end
  defp eval_compiled([head | tail], env) do
    procedure = eval_compiled(head, env)
    args = for arg <- tail, do: eval_compiled(arg, env)
    try do
      apply(procedure, args)
    rescue 
      BadFunctionError ->
        eval_compiled(head, env)
    end
  end

  def eval(lisp) do
    
  end
end